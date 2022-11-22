#!/usr/bin/env python3

from selenium import webdriver
from webdriver_manager.chrome import ChromeDriverManager
from webdriver_manager.core.utils import ChromeType
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.action_chains import ActionChains
from time import sleep
import pyotp
from pexpect import pxssh
import re
import pexpect
import logging
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--username', type=str, metavar="username")
parser.add_argument('--password', type=str, metavar="password")
parser.add_argument('--base_url', type=str, metavar="base_url")

args = parser.parse_args()

opts = Options()
chrome_service = Service(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install())
chrome_options = Options()
options = [
    "--headless",
    "--disable-gpu",
    "--window-size=1920,1200",
    "--ignore-certificate-errors",
    "--disable-extensions",
    "--no-sandbox",
    "--disable-dev-shm-usage"
]
for option in options:
    chrome_options.add_argument(option)

driver = webdriver.Chrome(service=chrome_service, options=chrome_options)

logger = logging.getLogger('ansible-easy-vpn')
logging.basicConfig()
logger.setLevel(logging.DEBUG)


def register_2fa(driver, base_url, username, password):
    logger.debug("Fetching {}".format(base_url))
    driver.get("https://wg.{}".format(base_url))
    sleep(0.5)
    logger.debug("Filling out the username field with {}".format(username))
    username_field = driver.find_element("id", "username-textfield")
    username_field.send_keys(username)
    sleep(0.5)
    logger.debug("Filling out the password field with {}".format(password))
    password_field = driver.find_element("id", "password-textfield")
    password_field.send_keys(password)
    sleep(0.5)
    logger.debug("Signing in...")
    submit_button = driver.find_element("id", "sign-in-button")
    submit_button.click()
    sleep(5)

    logger.debug("Clicking on 'Register device'")
    register_device = driver.find_element("id", "register-link")
    register_device.click()

    logger.debug("Getting the notifications.txt from the server")

    s = pxssh.pxssh()
    s.login(base_url, username, password)
    s.sendline('sudo cat /opt/docker/authelia/notification.txt')
    s.prompt()
    
    # Convert output to utf-8 due to pexpect weirdness
    notification = '\r\n'.join(s.before.decode('utf-8').splitlines()[1:])
    print(notification)

    token = re.search('token=(.*)', notification).group(1)
    driver.get("https://auth.{}/one-time-password/register?token={}".format(base_url, token))
    sleep(2)
    secret_field = driver.find_element("id", "secret-url")
    secret_field = secret_field.get_attribute("value")
    logger.debug("Scraping the TOTP secret")

    secret = re.search('secret=(.*)', secret_field).group(1)

    totp = pyotp.TOTP(secret)
    totp.now()
    logger.debug("Generating the OTP")

    otp_done_button = driver.find_element("xpath", "//*[contains(text(), 'Done')]")
    otp_done_button.click()
    sleep(2)
    logger.debug("Entering the OTP")

    actions = ActionChains(driver)
    actions.send_keys(totp.now())
    actions.perform()

    logger.debug("We're in!")
    sleep(1)
    return

def download_wg_config(driver, base_url, client):
    logger.debug("Opening wg.{} in the browser".format(base_url))
    driver.get("https://wg.{}".format(base_url))
    sleep(0.5)
    logger.debug("Clicking on the 'New Client' button")
    new_client_button = driver.find_element("xpath", "//*[contains(text(), 'New Client')]")
    new_client_button.click()
    sleep(0.5)
    logger.debug("Filling out the 'Name' field with {}".format(client))
    name_field = driver.find_element("xpath", "//input[@placeholder='Name']")
    name_field.send_keys(client)
    sleep(0.5)
    logger.debug("Clicking on 'Create'")
    create_button = driver.find_element("xpath", "//*[contains(text(), 'Create')]")
    create_button.click()
    sleep(0.5)
    logger.debug("Downloading the configuration")
    download_config = driver.find_element("xpath", "//a[@title='Download Configuration']")
    download_config.click()

    return

register_2fa(driver, args.base_url, args.username, args.password)
download_wg_config(driver, args.base_url, args.username)
