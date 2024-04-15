import sys
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager

def check_room_status(url):
    # Setup Chrome WebDriver
    service = Service(ChromeDriverManager().install())
    driver = webdriver.Chrome(service=service)

    try:
        # Navigate to the webpage passed as an argument
        driver.get(url)

        # Locate the table
        table = driver.find_element(By.CLASS_NAME, "room-status-table")

        # Find all rows in the table
        rows = table.find_elements(By.TAG_NAME, "tr")

        fail_count = 0  # Counter for failures based on conditions

        # Check each row in the table, skip header
        for row in rows[1:]:
            columns = row.find_elements(By.TAG_NAME, "td")
            room_number = columns[0].text
            floor_number = columns[1].text
            room_status = columns[2].text

            # Condition check example
            if floor_number == '8' and room_status != 'Clean':
                print(f"Check failed for Room {room_number} on Floor {floor_number}: Status is {room_status}")
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