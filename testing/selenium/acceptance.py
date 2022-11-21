#!/usr/bin/env python3

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.action_chains import ActionChains
from time import sleep
import pyotp
import re
import logging
import argparse

opts = Options()
opts.add_argument("--headless")
opts.add_experimental_option("prefs", {
    "profile.default_content_settings.popups": 0,
    "download.default_directory": "/home/petals",
    "download.prompt_for_download": False,
    "download.directory_upgrade": True,
    })
driver = webdriver.Chrome(options=opts)

logger = logging.getLogger('ansible-easy-vpn')
logging.basicConfig()
logger.setLevel(logging.DEBUG)


def register_2fa(driver, base_url):
    username = "petals"
    password = "z3Z4CIjOiO8aPnsMauDRvYxBG74="
    logger.debug("Fetching {}".format(base_url))
    driver.get("https://wg.{}".format(base_url))
    sleep(0.5)
    logger.debug("Filling out the username field with {}".format(username))
    username_field = driver.find_element("id", "username-textfield")
    username_field.send_keys("petals")
    sleep(0.5)
    logger.debug("Filling out the password field with {}".format(password))
    password_field = driver.find_element("id", "password-textfield")
    password_field.send_keys("z3Z4CIjOiO8aPnsMauDRvYxBG74=")
    sleep(0.5)
    logger.debug("Signing in...")
    submit_button = driver.find_element("id", "sign-in-button")
    submit_button.click()
    sleep(5)

    # logger.debug("Clicking on 'Register device'")
    #register_device = driver.find_element("id", "register-link")
    #register_device.click()

    logger.debug("Getting the OTP token from notifications.txt")
    with open("/opt/docker/authelia/notification.txt", 'r') as notification:
        token = re.search('token=(.*)', notification.read()).group(1)

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

def download_wg_config(driver, base_url):
    client = "petals"

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

url = "petals.rarepepes.faith"
register_2fa(driver, url)
download_wg_config(driver, url)
