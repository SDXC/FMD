function GetInfo()
  mangainfo.url=MaybeFillHost(module.RootURL, url)
  if http.get(mangainfo.url) then
    local x=TXQuery.Create(http.document)
    if mangainfo.title == '' then
      mangainfo.title = x.xpathstring('//strong[@class="bigChar"]')
    end
    local coverlink = x.xpathstring('//div[@class="a_center"]//img/@src')
    if coverlink ~= '' then
      if coverlink:find('^//') then coverlink = 'https:' .. coverlink; end
      mangainfo.coverlink=MaybeFillHost(module.RootURL, coverlink)
    end
    mangainfo.authors=x.xpathstringall('//*[@class="info"][2]//a[@class="dotUnder"]')
    --mangainfo.artists=x.xpathstringall('//*[@class="rightBox"]/a[contains(@href,"/?artist=")]')
    mangainfo.genres=x.xpathstringall('//*[@class="info"][3]//a[@class="dotUnder"]')
    mangainfo.genres = mangainfo.genres:gsub("%s+Manga", "")
    mangainfo.summary=x.xpathstring('//div[@class="summary"]//p')
    mangainfo.status = MangaInfoStatusIfPos(x.xpathstring('//*[@class="item_static"][1]'), 'Ongoing', 'Completed')
    x.xpathhrefall('//div[@class="listing listing8515 full"]//div//div//h3//a', mangainfo.chapterlinks, mangainfo.chapternames)
    InvertStrings(mangainfo.chapterlinks, mangainfo.chapternames)
    return no_error
  else
    return net_problem
  end
end

function GetPageNumber()
  if http.get(MaybeFillHost(module.rooturl,url)) then
    x=TXQuery.Create(http.Document)
    x.xpathstringall('//div[@id="centerDivVideo"]/img/@src', task.PageLinks)
    return true
  else
    return false
  end
end

function GetDirectoryPageNumber()
  if http.GET(AppendURLDelim(module.RootURL)..'/manga_list') then
    x = TXQuery.Create(http.Document)
    page = x.XPathString('//ul[@class="pager"]/li/a[last()-1]')
    page = page:gsub("Last (", "")
    page = page:gsub(")", "")
    page = tonumber(page)
    if page == nil then
      page = 1
    end
    return true
  else
    return false
  end
end

function GetNameAndLink()
  if http.get(module.rooturl..'/manga_list?page='..IncStr(url)) then
    x=TXQuery.Create(http.Document)
    x.xpathhrefall('//a[@class="item_movies_link"]', links, names)
    return no_error
  else
    return net_problem
  end
end

function BeforeDownloadImage()
  http.headers.values['Referer'] = task.PageContainerLinks.text
  return true
end

function Init()
  m=NewModule()
  m.category='English'
  m.website='KissManga'
  m.rooturl='https://kissmanga.org'
  m.lastupdated='Oct 08, 2020'
  m.ongetinfo='GetInfo'
  m.ongetpagenumber='GetPageNumber'
  m.ongetdirectorypagenumber='GetDirectoryPageNumber'
  m.ongetnameandlink='GetNameAndLink' 
  m.onbeforedownloadimage='BeforeDownloadImage'
end
