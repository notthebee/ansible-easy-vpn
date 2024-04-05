#!/usr/bin/env python3

from pexpect import pxssh
from selenium import webdriver
from selenium.common.exceptions import TimeoutException
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.webdriver.common.action_chains import ActionChains
from time import sleep

from os import mkdir
import argparse
import logging
import pyotp
import re


service = Service(executable_path=r"/snap/bin/chromium.chromedriver")

parser = argparse.ArgumentParser()
parser.add_argument("--username", type=str, metavar="username")
parser.add_argument("--password", type=str, metavar="password")
parser.add_argument("--base_url", type=str, metavar="base_url")
parser.add_argument("--ssh_agent", type=str, metavar="ssh_agent")

args = parser.parse_args()

chrome_options = Options()
prefs = {"download.default_directory": "/home/runner"}
chrome_options.add_experimental_option("prefs", prefs)
options = [
    "--headless",
    "--disable-gpu",
    "--window-size=1920,1200",
    "--ignore-certificate-errors",
    "--disable-extensions",
    "--no-sandbox",
    "--disable-dev-shm-usage",
]
for option in options:
    chrome_options.add_argument(option)

driver = webdriver.Chrome(service=service, options=chrome_options)

logger = logging.getLogger("ansible-easy-vpn")
logging.basicConfig()
logger.setLevel(logging.DEBUG)


def save_screenshot(screenshot_name):
    screenshot_path = "/home/runner/screenshots/"
    #screenshot_path = "/Users/notthebee/Downloads/"
    driver.save_screenshot(screenshot_path + screenshot_name)
    return

def register_2fa(driver, base_url, username, password, ssh_agent):
    logger.debug(f"Fetching wg.{base_url}")
    driver.get(f"https://wg.{base_url}")

    logger.debug(f"Filling out the username field with {username}")
    WebDriverWait(driver, 20).until(EC.presence_of_element_located((By.ID, "username-textfield"))).send_keys(username)
    save_screenshot("1_AutheliaUsername.png")
    logger.debug(f"Filling out the password field with {password}")
    WebDriverWait(driver, 20).until(EC.presence_of_element_located((By.ID, "password-textfield"))).send_keys(password)
    save_screenshot("2_AutheliaPassword.png")

    logger.debug("Signing in...")
    WebDriverWait(driver, 20).until(EC.element_to_be_clickable((By.ID, "sign-in-button"))).click()

    logger.debug("Clicking on 'Register device'")
    WebDriverWait(driver, 20).until(EC.element_to_be_clickable((By.ID, "register-link"))).click()
    save_screenshot("3_RegisterDevice.png")

    logger.debug("Clicking on 'One-Time Password'")
    WebDriverWait(driver, 20).until(EC.element_to_be_clickable((By.ID, "one-time-password-add"))).click()
    save_screenshot("4_OTP.png")

    logger.debug("Getting the notifications.txt from the server")
    s = pxssh.pxssh(options={"IdentityAgent": ssh_agent})
    s.login(base_url, username)
    s.sendline("show_2fa")
    s.prompt()
    # Convert output to utf-8 due to pexpect weirdness
    notification = "\r\n".join(s.before.decode("utf-8").splitlines()[1:])
    print(notification)
    token = re.search("single-use code: (.*)", notification).group(1)

    logger.debug("Entering the one-time code")
    WebDriverWait(driver, 20).until(EC.presence_of_element_located((By.ID, "one-time-code"))).click()
    save_screenshot("5_EnteringOTP.png")

    actions = ActionChains(driver)
    actions.send_keys(token)
    actions.perform()

    WebDriverWait(driver, 20).until(EC.element_to_be_clickable((By.ID, "dialog-verify"))).click()
    WebDriverWait(driver, 20).until(EC.element_to_be_clickable((By.ID, "dialog-next"))).click()

    WebDriverWait(driver, 20).until(EC.presence_of_element_located((By.ID, "secret-url"))).get_attribute("value")
    save_screenshot("6_SecetURL.png")

    logger.debug("Scraping the TOTP secret")

    secret = re.search("secret=(.*)", secret_field).group(1)

    totp = pyotp.TOTP(secret)
    totp.now()
    logger.debug("Generating the OTP")

    WebDriverWait(driver, 20).until(EC.element_to_be_clickable((By.ID, "dialog-next"))).click()

    sleep(3)

    logger.debug("Entering the OTP")

    actions = ActionChains(driver)
    actions.send_keys(totp.now())
    actions.perform()

    logger.debug("We're in!")
    sleep(1)
    return secret


def download_wg_config(driver, base_url, client, secret):
    logger.debug(f"Opening wg.{base_url} in the browser")
    driver.get(f"https://wg.{base_url}")

    save_screenshot("7_AutheliaOTPEnter.png")
    totp = pyotp.TOTP(secret)


    logger.debug("Clicking on the 'New Client' button")

    attempts = 0
    while attempts < 5:
        try:
            actions = ActionChains(driver)
            actions.send_keys(totp.now())
            actions.perform()

            logger.debug(f"Opening wg.{base_url} in the browser")
            driver.get(f"https://wg.{base_url}")

            WebDriverWait(driver, 5).until(EC.element_to_be_clickable((By.XPATH, "//*[contains(text(), 'New Client')]"))).click()
            save_screenshot("8_WGEeasy_NewClient.png")
            break
        except TimeoutException:
            attempts += 1

    logger.debug(f"Filling out the 'Name' field with {client}")
    WebDriverWait(driver, 20).until(EC.presence_of_element_located((By.XPATH, "//input[@placeholder='Name']"))).send_keys(client)
    save_screenshot("9_WGEeasy_NewClientName.png")

    logger.debug("Clicking on 'Create'")
    WebDriverWait(driver, 20).until(EC.element_to_be_clickable((By.XPATH, "//*[contains(text(), 'Create')]"))).click()

    save_screenshot("10_WGEeasy_ClientCreated.png")
    logger.debug("Downloading the configuration")
    WebDriverWait(driver, 20).until(EC.element_to_be_clickable((By.XPATH, "//a[@title='Download Configuration']"))).click()
    sleep(2)

    return


secret = register_2fa(driver, args.base_url, args.username, args.password, args.ssh_agent)
download_wg_config(driver, args.base_url, args.username, secret)
