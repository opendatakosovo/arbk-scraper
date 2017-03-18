# ARBK Scraper
A Watir ruby script to scrape business registration data from ARBK's website.

## Requirements
- [MongoDB](https://www.mongodb.com/): to persist the scraped data.
- [ruby](https://www.ruby-lang.org/en/): to run the ruby script.
- [ruby-dev](http://stackoverflow.com/questions/4304438/gem-install-failed-to-build-gem-native-extension-cant-find-header-files): to install the ruby mongo driver.
- [Make](http://stackoverflow.com/questions/33201630/install-gem-gives-failed-to-build-gem-native-extension): to install ruby gems.
- [zlib](http://askubuntu.com/a/508937): we need to install the watir-nokogiri gem which depends on zlib (or else we get the error: _"zlib is missing; necessary for building libxml2"_).
- [ChromeDriver - WebDriver for Chrome](https://sites.google.com/a/chromium.org/chromedriver/): to interact with the Chrome driver via the watir ruby gem.

## Ruby Dependencies
- [rubygems](https://rubygems.org/).
- [mongo-ruby-driver](https://github.com/mongodb/mongo-ruby-driver): a mongo driver.
- [watir](http://watir.github.io/): interface to script interactions with the Chrome browser.
- [nokogiri](https://github.com/sparklemotion/nokogiri): an HTML, XML, SAX, and Reader parser. Among Nokogiri's many features is the ability to search documents via XPath or CSS3 selectors.
