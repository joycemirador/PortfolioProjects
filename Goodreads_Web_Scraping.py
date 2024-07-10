import time
import pandas as pd
import selenium.common.exceptions
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.wait import WebDriverWait
from selenium.webdriver.support import expected_conditions as ec

chrome_options = webdriver.ChromeOptions()
chrome_options.add_experimental_option('detach', True)
driver = webdriver.Chrome(options=chrome_options)
driver.get('https://www.goodreads.com/')

best_books_2023_link = driver.find_element(By.LINK_TEXT, 'Best Books 2023')
best_books_2023_link.click()
dismiss_button = driver.find_element(By.XPATH, '//*[@id="gcaLanding"]/div[3]/div/div/div[1]/button/img')
dismiss_button.click()

categories = ['Fiction', 'Historical Fiction', 'Mystery & Thriller', 'Romance', 'Romantasy', 'Fantasy',
              'Science Fiction', 'Horror', 'Young Adult Fantasy', 'Young Adult Fiction', 'Debut Novel',
              'Nonfiction', 'Memoir & Autobiography', 'History & Biography', 'Humor']
data = {'title': [],
        'authors': [],
        'genres': [],
        'rating': [],
        'num_of_ratings': [],
        'num_of_votes': [],
        'num_of_reviews': [],
        'num_of_pages': [],
        'language': [],
        'awards': [],
        'publication_date': [],
        'publisher': [],
        'isbn': [],
        'description': []}
wait = WebDriverWait(driver, 10)


def scrape_genre_author_award_lists():
    author = wait.until(ec.presence_of_all_elements_located((By.CLASS_NAME, 'ContributorLink__name')))
    author_list = []
    for y in range(len(author)):
        author_list.append(author[y].text)
    authors = ', '.join(author_list)

    genres = wait.until(ec.presence_of_all_elements_located(
        (By.XPATH, '//*[contains(@href, "https://www.goodreads.com/genres/")]')))
    genre_list = []
    for i in range(len(genres)):
        genre_list.append(genres[i].text)
    genres = ', '.join(genre_list)

    try:
        awards = wait.until(ec.presence_of_all_elements_located((By.CSS_SELECTOR, '[data-testid="award"]')))
        award_list = []
        for x in range(len(awards)):
            award_list.append(awards[x].text)
        awards = ', '.join(award_list)
    except selenium.common.exceptions.TimeoutException:
        awards = 'N/A'

    # Store the data into the dataframe
    data['authors'].append(authors)
    data['genres'].append(genres)
    data['awards'].append(awards)


def scrape_more_book_details():
    # Click the 'Book details & editions' link to get the book publisher, language and ISBN
    more_details_link = wait.until(ec.element_to_be_clickable(
        (By.CSS_SELECTOR, '[aria-label="Book details and editions"]')))
    more_details_link.send_keys(Keys.ENTER)

    # Some books have a different division in its XPATH and either has no ISBN or language data.
    # For books with no language data, the ISBN will be stored under the language column. This will be cleaned later on.
    # XPATH 1 with ISBN:
    try:
        language = driver.find_element(
            By.XPATH, '//*[@id="__next"]/div[2]/main/div[1]/div[2]/div[2]/div[2]/div[7]/div/span[2]/div[1]/span/'
                      'div/dl/div[4]/dd/div/div[1]').text
    except selenium.common.exceptions.NoSuchElementException:
        # XPATH 1 no ISBN:
        try:
            language = driver.find_element(
                By.XPATH, '//*[@id="__next"]/div[2]/main/div[1]/div[2]/div[2]/div[2]/div[7]/div/span[2]/div[1]/'
                          'span/div/dl/div[3]/dd/div/div[1]').text
            isbn = 'N/A'
        # XPATH 2 with ISBN:
        except selenium.common.exceptions.NoSuchElementException:
            try:
                language = driver.find_element(
                    By.XPATH, '//*[@id="__next"]/div[2]/main/div[1]/div[2]/div[2]/div[2]/div[6]/div/span[2]/div[1]/'
                              'span/div/dl/div[4]/dd/div/div[1]').text
                isbn = driver.find_element(
                    By.XPATH, '//*[@id="__next"]/div[2]/main/div[1]/div[2]/div[2]/div[2]/div[6]/div/span[2]/div[1]/'
                              'span/div/dl/div[3]/dd/div/div[1]').text
            # XPATH 2 no ISBN:
            except selenium.common.exceptions.NoSuchElementException:
                language = driver.find_element(
                    By.XPATH, '//*[@id="__next"]/div[2]/main/div[1]/div[2]/div[2]/div[2]/div[6]/div/span[2]/'
                              'div[1]/span/div/dl/div[3]/dd/div/div[1]').text
                isbn = 'N/A'
    else:
        isbn = driver.find_element(
            By.XPATH, '//*[@id="__next"]/div[2]/main/div[1]/div[2]/div[2]/div[2]/div[7]/div/span[2]/div[1]/span/'
                      'div/dl/div[3]/dd/div/div[1]').text
    finally:
        try:
            # XPATH 1:
            publisher = (driver.find_element(
                By.XPATH, '//*[@id="__next"]/div[2]/main/div[1]/div[2]/div[2]/div[2]/div[7]/div/span[2]/div[1]/'
                          'span/div/dl/div[2]/dd/div/div[1]').text.split())
            publisher = ' '.join(publisher[4:])
        except selenium.common.exceptions.NoSuchElementException:
            # XPATH 2:
            publisher = (driver.find_element(
                By.XPATH, '//*[@id="__next"]/div[2]/main/div[1]/div[2]/div[2]/div[2]/div[6]/div/span[2]/div[1]/'
                          'span/div/dl/div[2]/dd/div/div[1]').text.split())
            publisher = ' '.join(publisher[4:])

    # Store the data into the dataframe
    data['language'].append(language)
    data['isbn'].append(isbn)
    data['publisher'].append(publisher)


def scrape_data(id):
    # The division number starts at 2.
    num_of_books = 2

    scraping_completed = False
    while not scraping_completed:
        try:
            num_of_votes = (wait.until(ec.presence_of_element_located((By.XPATH,
                            f'//*[@id="poll_{str(278863 + id)}"]/div[2]/div[{num_of_books}]/strong'))).text
                            .replace(',', '').replace(' votes', ''))
        except selenium.common.exceptions.TimeoutException:
            return

        # Click the link to go to the webpage where the book details are stored
        book_link = wait.until(ec.element_to_be_clickable(
            (By.XPATH, f'//*[@id="poll_{str(278863 + id)}"]/div[2]/div[{num_of_books}]/div[1]/div')))
        book_link.click()

        title = wait.until(ec.presence_of_element_located(
            (By.XPATH, '//*[@id="__next"]/div[2]/main/div[1]/div[2]/div[2]/div[1]/div[1]/h1'))).text
        rating = wait.until(ec.presence_of_element_located((By.CLASS_NAME, 'RatingStatistics__rating'))).text
        description = wait.until(ec.presence_of_element_located((By.CLASS_NAME, 'Formatted'))).text

        num_of_ratings_reviews = (wait.until(ec.presence_of_element_located((By.CLASS_NAME, 'RatingStatistics__meta')))
                                  .text.replace(',', '').split())
        num_of_ratings = num_of_ratings_reviews[0]
        num_of_reviews = num_of_ratings_reviews[1].replace('ratings', '')

        pages_and_publication = (wait.until(ec.presence_of_element_located((By.CLASS_NAME, 'FeaturedDetails')))
                                 .text.split())
        num_of_pages = pages_and_publication[0]
        publication_date = ' '.join(pages_and_publication[-3:])

        scrape_genre_author_award_lists()
        scrape_more_book_details()

        # Store the data into the dataframe
        data['title'].append(title)
        data['rating'].append(rating)
        data['num_of_ratings'].append(num_of_ratings)
        data['num_of_votes'].append(num_of_votes)
        data['num_of_reviews'].append(num_of_reviews)
        data['num_of_pages'].append(num_of_pages)
        data['publication_date'].append(publication_date)
        data['description'].append(description)

        driver.back()
        num_of_books += 1


# There is a designated poll id per category, and it increases by 1 as it goes down all the categories up to 'Humor'
poll_id = 0

# Go through all the categories for Best Books in 2023
for category in categories:
    category_link = wait.until(ec.element_to_be_clickable((By.LINK_TEXT, f'{category}')))
    category_link.click()
    scrape_data(id=poll_id)
    driver.back()
    time.sleep(10)
    poll_id += 1

driver.quit()

# Convert data into a dataframe
df = pd.DataFrame.from_dict(data)

# Convert dataframe into a csv file
df.to_csv('goodreads_best_books_2023.csv', index=False)
