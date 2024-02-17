#!/usr/bin/env python
from bs4 import BeautifulSoup as Soup
from bs4 import SoupStrainer as Strainer

detail = Strainer('table', {'id': 'searchResult'})
with open("html.txt") as fp:
    soup = Soup(fp, features="html.parser", parse_only=detail)


trs = soup.find_all("tr")

print(trs)
