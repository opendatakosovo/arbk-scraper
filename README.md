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

## Possible Errors
Errors can occur during the scraping process. The following is a list of possible errors.

 1. no such window: target window already closed\nfrom unknown error: web view not found\n  (Session info: chrome=57.0.2987.110)\n  (Driver info: chromedriver=2.28.455517 (2c6d2707d8ea850c862f04ac066724273981e88f),platform=Mac OS X 10.12.3 x86_64).
 2. unknown error: Element <input name="ctl00$MainContent$ctl00$Submit1" type="submit" id="MainContent_ctl00_Submit1" value="Kërko"> is not clickable at point (93, 334). Other element would receive the click: <li class=\"sf-megamenu-wrapper odd sf-item-1 sf-depth-1 sf-total-children-5 sf-parent-children-5 sf-single-children-0 menuparent\">...</li>\n  (Session info: chrome=57.0.2987.110)\n  (Driver info: chromedriver=2.28.455517 (2c6d2707d8ea850c862f04ac066724273981e88f),platform=Mac OS X 10.12.3 x86_64).
 3. Net::ReadTimeout.
 4. undefined local variable or method `browser' for main:Object.
 5. unexpected alert open: {Alert text : [object Object]}\n  (Session info: chrome=57.0.2987.110)\n  (Driver info: chromedriver=2.28.455517 (2c6d2707d8ea850c862f04ac066724273981e88f),platform=Mac OS X 10.12.3 x86_64).
 6. timed out after 30 seconds, waiting for #<Watir::TextField: located: false; {:id=>"MainContent_ctl00_txtNumriBiznesit", :tag_name=>"input"}> to be located.
 7. no such session\n  (Driver info: chromedriver=2.28.455517 (2c6d2707d8ea850c862f04ac066724273981e88f),platform=Mac OS X 10.12.3 x86_64).
 8. Too many failed attempts to load search page: Net::ReadTimeout.
 9. timed out after 30 seconds, waiting for #<Watir::Anchor: located: false; {:xpath=>"//table[@class='views-table cols-4']/tbody//td/a", :tag_name=>"a"}> to be located.
 10. Too many failed attempts to load page via anchor click: timed out after 30 seconds, waiting for #<Watir::Anchor: located: false; {:xpath=>"//table[@class='views-table cols-4']/tbody//td/a", :tag_name=>"a"}> to be located.
 11. unknown error: Element <input name=\"ctl00$MainContent$ctl00$Submit1\" type="submit" id="MainContent_ctl00_Submit1" value="Kërko"> is not clickable at point (93, 275). Other element would receive the click: <div class="hero-content-primary" style="height: auto;">...</div>\n  (Session info: chrome=57.0.2987.110)\n  (Driver info: chromedriver=2.28.455517 (2c6d2707d8ea850c862f04ac066724273981e88f),platform=Mac OS X 10.12.3 x86_64).
 12. browser window was closed.
 
You can count how many of each error type occurs with the following query:

```
db.errors.aggregate([
  {$group : 
    { _id : '$errorMsg', count : {$sum : 1}}
  }
]).pretty()
```
