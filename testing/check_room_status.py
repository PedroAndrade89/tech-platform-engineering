import sys
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager

def check_room_status(url):
    # Setup Chrome WebDriver
    chrome_options = Options()
    chrome_options.add_argument("--headless")  # Run Chrome in headless mode.
    chrome_options.add_argument("--no-sandbox")  # Bypass OS security model, crucial on Linux
    chrome_options.add_argument("--disable-gpu")  # Disable GPU hardware acceleration
    chrome_options.add_argument("--disable-dev-shm-usage")  # Overcome limited resource problems
    chrome_options.add_argument("--remote-debugging-port=9222")  # Remote debugging port
    service = Service(ChromeDriverManager().install())

    driver = webdriver.Chrome(service=service, options=chrome_options)

    fail_count = 0  # Counter for failures based on conditions

    try:
        # Navigate to the webpage
        driver.get(url)

        # Get the title of the page
        page_title = driver.title
        print("The title of the page is:", page_title)

        # Check if the title is 'React App'
        if page_title == "React App":
            print("Title verification successful.")
        else:
            print("Title verification failed.")
            fail_count += 1


        # Check if there were any failures
        if fail_count > 0:
            return 1  # Return 1 to indicate failure

        return 0  # Return 0 to indicate success

    except Exception as e:
        print(f"An error occurred: {e}")
        return 2  # Return 2 to indicate an error

    finally:
        driver.quit()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python check_room_status.py <URL>")
        sys.exit(3)  # Return 3 to indicate incorrect usage

    url = sys.argv[1]
    exit_code = check_room_status(url)
    sys.exit(exit_code)