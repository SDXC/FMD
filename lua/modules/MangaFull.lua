function getinfo()
  mangainfo.url=MaybeFillHost(module.RootURL, url)
  if http.get(mangainfo.url) then
      local x=TXQuery.Create(http.document)
	  mangainfo.title = x.xpathstring('//div[@class="media-body"]//h1')
	  mangainfo.coverlink=MaybeFillHost(module.RootURL, x.xpathstring('//div[@class="media-left cover-detail"]//img/@src'))
      mangainfo.authors=''
	  mangainfo.genres=''
	  mangainfo.summary=x.xpathstring('//div[@class="manga-content"]/p')
	  
	  local v=x.xpath('//div[@class="chapter-list"]/ul/li[@class="row"]//a')
	  for i=1,v.count do
		local v1=v.get(i)
		mangainfo.chapterlinks.add(v1.getattribute('href'))
		mangainfo.chapternames.add(v1.getattribute('title'))
      end
	  InvertStrings(mangainfo.chapterlinks,mangainfo.chapternames)
	  return no_error
  else
    return net_problem
  end
end

function getpagenumber()
	task.pagelinks.clear()
	if http.get(MaybeFillHost(module.rooturl,url .. '/0')) then
	   TXQuery.Create(http.Document).xpathstringall('//div[@class="each-page"]//img/@src', task.pagelinks)
	   return true
	end
	return false
end

function getnameandlink()
	
end


function Init()
  local m = NewModule()
  m.website = 'mangafull'
  m.rooturl = 'https://mangafull.org'
  m.category = 'English'
  m.lastupdated='May 14, 2019'
  m.sortedlist = true
  m.ongetinfo='getinfo'
  m.ongetpagenumber='getpagenumber'
end