#!/usr/local/bin/awk -bE

# Populate 'Data:Wikipedia statistics/exturls.tab' on Commons 
#                      
# GitHub: https://github.com/greencardamom/Numberofurl
#
# Copyright (c) 2025 User:GreenC (on en.wikipeda.org)
# Adapted from numberof: https://github.com/greencardamom/Numberof
# License: MIT 
#
# Requires: https://github.com/greencardamom/Findlinks
#

BEGIN { # Bot cfg

  _defaults = "home      = /home/greenc/toolforge/numberofurl/ \
               emailfp   = /home/greenc/toolforge/scripts/secrets/greenc.email \
               findlinks = /home/greenc/toolforge/findlinks/findlinks.awk \
               version   = 1.0 \
               copyright = 2025"

  asplit(G, _defaults, "[ ]*[=][ ]*", "[ ]{9,}")

  BotName = "numberofurl"
  Home = G["home"]
  Agent = "numberofurl acre User:GreenC enwiki" 
  Engine = 3

  G["email"] = strip(readfile(G["emailfp"]))

  G["datau"] = G["home"] "datau.tab"
  G["datac"] = G["home"] "datac.tab"
  G["dump"]  = G["home"] "dump/"
  # G["apitail"] = "&format=json&formatversion=2&maxlag=4"
  G["apitail"] = "&format=json&formatversion=2"

  # 1-off special sites with no language sub-domains
  # eg. site www.wikidata is represented here as www=wikidata
  G["specials"] = "www=wikifunctions&www=wikidata&www=wikisource&meta=wikimedia&commons=wikimedia&incubator=wikimedia&foundation=wikimedia&wikimania=wikimedia&wikitech=wikimedia&donate=wikimedia&species=wikimedia&beta=wikiversity"

  # Set to 0 and it won't upload to Commons, for testing
  G["doupload"] = 1

}

@include "botwiki"
@include "library"
@include "json"

BEGIN { # Bot run

    # an empty json template 
    if( ! checkexists(G["home"] "apiclosed.json")) {
        print "Unable to find " G["home"] "apiclosed.json"
        exit
    }

    # set to "commons" and it will read conf.tab on Commons .. otherwise "api" generates from API:SiteMatrix
    G["confloc"] = getconf()

    Optind = Opterr = 1
    while ((C = getopt(ARGC, ARGV, "d")) != -1) {
        if(C == "d")
            G["skipdump"] = 1
    }

    getdump()
    dataconfig(G["datac"])    # create what used to be Data:Wikipedia_statistics/config.tab via API:SiteMatrix
    dataurltab(G["datau"])    # create Data:Wikipedia_statistics/exturls.tab

}


#
# Download dump of URLs - takes a while
#
function getdump(  command,wds,a,i) {

  if(G["skipdump"]) 
      return

  # Clear the dump directory
  command = "ls " shquote(G["dump"]) " | wc -l"
  wds = strip(sys2var(command))
  if(int(wds) > 0)
      system("rm " shquote(G["dump"]) "*")

  # Generate allwikis.txt - a current list of wikis
  command = G["findlinks"] " -a -q -w " shquote(G["dump"])
  system(command)

  # Remove certain sites 
  for(i = 1; i <= splitn(G["dump"] "allwikis.txt", a, i); i++) {
      if(a[i] !~ "commonswiki_p")
          print a[i] >> G["dump"] "allwikis.txt.t"
  }
  close(G["dump"] "allwikis.txt.t")
  command = "mv " shquote(G["dump"] "allwikis.txt.t") " " shquote(G["dump"] "allwikis.txt")
  system(command)

  # Generate a dump of all URLs in namespace 0 and 6. 
  # It will be in multiple files named adn.com.<sitename> where "adn" means "all domain names" and "com" is a placeholder
  command = G["findlinks"] " -q -s ALL -n " shquote("0 6") " -d ALL -w " shquote(G["dump"])
  system(command)

}

#
# Currrent date/time in UTC
#
function currenttimeUTC() {
  return gsubi("GMT", "UTC", strftime(PROCINFO["strftime"], systime(), 1))
}

#
# Generate n-number of tabs
#
function t(n, r,i) {
  for(i = 1; i <= n; i++)
      r = r "\t"
  return r
}

#
# Abort and email if unable to retrieve page to avoid corrupting data.tab
#
function getpage(s,status,  fp,i) {

  for(i = 1; i <= 10; i++) {
      if(i == 2 && status ~ "closed")          # If closed site MW API may not have data available..
          return readfile(G["home"] "apiclosed.json") # Return manufactured JSON with data values of 0
      fp = sys2var(s)
      #stdErr(s)
      #stdErr(fp)
      if(! empty(fp) && fp ~ "(schema|statistics|sitematrix)")
          return fp
      sleep(30)
  }

  email(Exe["from_email"], Exe["to_email"], "NUMBEROFURL COMPLETELY ABORTED ITS RUN because it failed to getpage(" s ")", "")
  exit

}

#
# Determine where to read configuration from, API:SiteMatrix or conf.tab on Commons
#
function getconf( fp,i,a) {

  return "api"  # always use api for now

  # fp = getpage(Exe["wikiget"] " -l en -w 'Template:NUMBEROF/conf'")

  for(i = 1; i <= splitn(fp, a, i); i++) {
      if(a[i] ~ "^[*][ ]*[Cc]ommons")
          return "commons"
  }
  return "api"

}

#
# Generate JSON header
#
function jsonhead(description, sources, header, dataf,  c,i,a,b) {

  print "{" > dataf
  print t(1) "\"license\": \"CC0-1.0\"," >> dataf
  print t(1) "\"description\": {" >> dataf
  print t(2) "\"en\": \"" description "\"" >> dataf
  print t(1) "}," >> dataf
  print t(1) "\"sources\": \"" sources "\"," >> dataf
  print t(1) "\"schema\": {" >> dataf
  print t(2) "\"fields\": [" >> dataf

  c = split(header, a, /[&]/)
  for(i = 1; i <= c; i++) {
      split(a[i], b, /[=]/)
      print t(3) "{" >> dataf
      print t(4) "\"name\": \"" b[1] "\"," >> dataf
      print t(4) "\"type\": \"" b[2] "\"," >> dataf
      print t(4) "\"title\": {" >> dataf
      print t(5) "\"en\": \"" b[1] "\"" >> dataf
      print t(4) "}" >> dataf
      printf t(3) "}" >> dataf
      if(i != c) print "," >> dataf
      else print "" >> dataf
  }

  print t(2) "]" >> dataf
  print t(1) "}," >> dataf
  print t(1) "\"data\": [" >> dataf

}


#
# Generate conf.tab
#   see files sitematrix.json and sitematrix.awkjson for example layout
#
function dataconfig(datac,  a,i,s,sn,jsona,configfp,language,site,status,countofsites,desc,source,header,url) {

  desc   = "Meta statistics for Wikimedia projects. Last update: " currenttimeUTC() 
  source = "Data source: Calculated from [[:mw:API:Sitematrix]] and posted by [https://github.com/greencardamom/Numberof Numberof bot]. This page is generated automatically, manual changes will be overwritten."
  header = "language=string&project=string&status=string"
  jsonhead(desc, source, header, datac)

  configfp = getpage(Exe["wget"] " --user-agent=" shquote(Agent) " -q -O- " shquote("https://en.wikipedia.org/w/api.php?action=sitematrix" G["apitail"]), "")
  if(query_json(configfp, jsona) >= 0) {

      for(i = 0; i <= jsona["sitematrix","count"]; i++) {
          language = jsona["sitematrix",i,"code"]
   
          # For the below see https://meta.wikimedia.org/wiki/List_of_Wikipedias#Nonstandard_language_codes

          if(language == "be-x-old") language = "be-tarask"
          else if(language == "gsw") language = "als"
          else if(language == "lzh") language = "zh-classical"
          else if(language == "nan") language = "zh-min-nan"
          else if(language == "rup") language = "roa-rup"
          else if(language == "sgs") language = "bat-smg"
          else if(language == "vro") language = "fiu-vro"
          else if(language == "yue") language = "zh-yue"

          if(!empty(language)) {
              countofsites = jsona["sitematrix",i,"site","0"]

              # Some sites ("mo") have zero sites, skip
              if(countofsites > 0) {
                  for(sn = 1; sn <= countofsites; sn++) {
                      site = jsona["sitematrix",i,"site",sn,"code"]
                      if(site == "wiki") site = "wikipedia"
                      status = "active"
                      if(jsona["sitematrix",i,"site",sn,"closed"] == 1) status = "closed"
                      print t(2) "[\"" language "\",\"" site "\",\"" status "\"]," >> datac
                  }
              }
          }
      }

      # specials
      s = split(G["specials"], a, /[&]/)
      for(i = 1; i <= s; i++) {
          split(a[i], b, /[=]/)
          printf t(2) "[\"" b[1] "\",\"" b[2] "\",\"active\"]" >> datac
          if(i < s) print "," >> datac
          else print "" >> datac
      }

  }
  else {
      email(Exe["from_email"], Exe["to_email"], "ABORTED: Numberofurl failed in dataconfig()", "")
      exit
  }

  print "\n\t]\n}" >> datac
  close(datac)

  # Already uploaded by Numberof package
  #if(G["doupload"])
  #    upload(readfile(datac), "Data:Wikipedia statistics/meta.tab", "Update statistics", G["home"] "log", BotName, "commons", "wikimedia")

}

#
# Generate exturls.tab 
#
function dataurltab(data,  c,i,x,cfgfp,k,lang,site,status,jsona,stati,statn,desc,source,header,siteT) {

  desc = "Wikimedia external URL statistics. See User:GreenC/Exturls for docs. Last update: " currenttimeUTC()
  source = "Data source: Calculated from [[:mw:API:Siteinfo]] and [https://github.com/greencardamom/Findlinks Findlinks]. Posted by [https://github.com/greencardamom/Numberofurl Numberofurl bot]. This page is generated automatically, manual changes will be overwritten."
  header = "site=string&pages=number&ialiburls=number&uniqialiburls=number&pagesialiburls=number&urls=number&uniqurls=number&pagesurls=number&waybackurls=number&uniqwaybackurls=number&pageswaybackurls=number&archivetodayurls=number&uniqarchivetodayurls=number&pagesarchivetodayurls=number&webciteurls=number&uniqwebciteurls=number&pageswebciteurls=number"
  jsonhead(desc, source, header, data)
  
  # Get the configuration JSON
  if(G["confloc"] == "api")
      cfgfp = readfile(G["datac"])
  else
      cfgfp = getpage(Exe["wikiget"] " -l commons -w 'Data:Wikipedia statistics/config.tab'")

  c = spliti("pages|ialiburls|uniqialiburls|pagesialiburls|urls|uniqurls|pagesurls|waybackurls|uniqwaybackurls|pageswaybackurls|archivetodayurls|uniqarchivetodayurls|pagesarchivetodayurls|webciteurls|uniqwebciteurls|pageswebciteurls", stati, "|")
  split("pages|ialiburls|uniqialiburls|pagesialiburls|urls|uniqurls|pagesurls|waybackurls|uniqwaybackurls|pageswaybackurls|archivetodayurls|uniqarchivetodayurls|pagesarchivetodayurls|webciteurls|uniqwebciteurls|pageswebciteurls", statn, "|")

  if( query_json(cfgfp, jsona) >= 0) {                   # Convert JSON cfgfp to awk associate array jsona[]  
      for(k = 1; k <= jsona["data","0"]; k++) {
          lang = jsona["data",k,"1"]
          site = jsona["data",k,"2"]
          status = jsona["data",k,"3"]

          # enable to run for one site only
          #ss=lang site
          #if(ss !~ "tarask") continue

          if(status != "active")
            continue

          if(lang == "commons" && site == "wikimedia")
            continue

          if(lang == "total") 
            continue

          stati["pages"] = pagesF(lang "." site ".org")

          # special case names 

          if(site == "wikipedia") 
            site = "wiki"   

          if(lang == "be-tarask") {
            lang = "be-x-old" 
            site = "wiki"
          }
          else if(site == "wikidata" && lang == "www")  {
            lang = "wikidata"
            site = "wiki"
          }
          else if(site == "wikifunctions" && lang == "www")  {
            lang = "wikifunctions"
            site = "wiki"
          }
          else if(site == "wikisource" && lang == "www")  {
            lang = "wikisource"
            site = "wiki"
          }
          else if(site == "wikimedia" && lang == "meta")  {
            lang = "meta"
            site = "wiki"
          }
          else if(site == "wikimedia" && lang == "incubator")  {
            lang = "incubator"
            site = "wiki"
          }
          else if(site == "wikimedia" && lang == "foundation")  {
            lang = "foundation"
            site = "wiki"
          }
          else if(site == "wikimedia" && lang == "wikimania")  {
            lang = "wikimania"
            site = "wiki"
          }
          else if(site == "wikimedia" && lang == "wikitech")  {
            lang = "wikitech"
            site = "wiki"
          }
          else if(site == "wikimedia" && lang == "donate")  {
            lang = "donate"
            site = "wiki"
          }
          else if(site == "wikimedia" && lang == "species")  {
            lang = "species"
            site = "wiki"
          }

          chDir(G["dump"])

          x = ialiburlsF(lang site)
          stati["ialiburls"] = splitx(x, "[ ]", 1)
          stati["uniqialiburls"] = splitx(x, "[ ]", 2)
          stati["pagesialiburls"] = splitx(x, "[ ]", 3)

          x = urlsF(lang site)
          stati["urls"] = splitx(x, "[ ]", 1)
          stati["uniqurls"] = splitx(x, "[ ]", 2)
          stati["pagesurls"] = splitx(x, "[ ]", 3)

          x = waybackurlsF(lang site)
          stati["waybackurls"] = splitx(x, "[ ]", 1)
          stati["uniqwaybackurls"] = splitx(x, "[ ]", 2)
          stati["pageswaybackurls"] = splitx(x, "[ ]", 3)

          x = archivetodayurlsF(lang site)
          stati["archivetodayurls"] = splitx(x, "[ ]", 1)
          stati["uniqarchivetodayurls"] = splitx(x, "[ ]", 2)
          stati["pagesarchivetodayurls"] = splitx(x, "[ ]", 3)

          x = webciteurlsF(lang site)
          stati["webciteurls"] = splitx(x, "[ ]", 1)
          stati["uniqwebciteurls"] = splitx(x, "[ ]", 2)
          stati["pageswebciteurls"] = splitx(x, "[ ]", 3)

          chDir(G["home"])

          # revert special case names

          if(lang == "be-x-old") {
            lang = "be-tarask"
          }   
          else if(site == "wiki" && lang == "wikidata") {
            site = "wikidata"
            lang = "www"
          }
          else if(site == "wiki" && lang == "wikifunctions") {
            site = "wikifunctions"
            lang = "www"
          }
          else if(site == "wiki" && lang == "wikisource") {
            site = "wikisource"
            lang = "www"
          }
          else if(site == "wiki" && lang == "meta") {
            site = "wikimedia"
            lang = "meta"
          }
          else if(site == "wiki" && lang == "incubator") {
            site = "wikimedia"
            lang = "incubator"
          }
          else if(site == "wiki" && lang == "foundation") {
            site = "wikimedia"
            lang = "foundation"
          }
          else if(site == "wiki" && lang == "wikimania") {
            site = "wikimedia"
            lang = "wikimania"
          }
          else if(site == "wiki" && lang == "wikitech") {
            site = "wikimedia"
            lang = "wikitech"
          }
          else if(site == "wiki" && lang == "donate") {
            site = "wikimedia"
            lang = "donate"
          }
          else if(site == "wiki" && lang == "species") {
            site = "wikimedia"
            lang = "species"
          }

          if(site == "wiki") 
            site = "wikipedia"   

          printf t(2) "[\"" lang "." site "\"," >> data
          for(i = 1; i <= c; i++) { 

              printf stati[statn[i]] >> data
              if(i != c) 
                  printf "," >> data

              T[site][statn[i]] = T[site][statn[i]] + stati[statn[i]]        # totals ticker (active and closed)

              #if(status == "active") 
              #    TA[site][statn[i]] = TA[site][statn[i]] + stati[statn[i]]  # totals ticker (active only)
              #if(status == "closed")
              #    TC[site][statn[i]] = TC[site][statn[i]] + stati[statn[i]]  # totals ticker (closed only)

          }
          print "]," >> data
          close(data)
      }
  } 
  
  # Totals active and closed
  for(siteT in T) {
      printf t(2) "[\"total." siteT "\"," >> data
      for(i = 1; i <= c; i++) {
          printf T[siteT][statn[i]] >> data
          TT[statn[i]] = TT[statn[i]] + T[siteT][statn[i]]  # Grand total ticker
          if(i != c) printf "," >> data
      }
      print "]," >> data
  }

  # Totals active only
#  for(siteT in TA) {
#      printf t(2) "[\"totalactive." siteT "\"," >> data
#      for(i = 1; i <= c; i++) {
#          printf TA[siteT][statn[i]] >> data
#          if(i != c) printf "," >> data
#      }
#      print "]," >> data
#  }

  # Totals closed only
#  for(siteT in TC) {
#      printf t(2) "[\"totalclosed." siteT "\"," >> data
#      for(i = 1; i <= c; i++) {
#          printf TC[siteT][statn[i]] >> data
#          if(i != c) printf "," >> data
#      }
#      print "]," >> data
#  }

  # Grand total all sites combined, active and closed
  printf t(2) "[\"total.all\"," >> data
  for(i = 1; i <= c; i++) {
      printf TT[statn[i]] >> data
      if(i != c) printf "," >> data
  }

  print "]\n" >> data
  print t(1) "]," >> data
  print t(1) "\"mediawikiCategories\": [" >> data
  print t(2) "{" >> data
  print t(3) "\"name\": \"Wikimedia-related tabular data\"," >> data
  print t(3) "\"sort\": \"statistics\"" >> data
  print t(2) "}" >> data
  print t(1) "]" >> data
  print "}" >> data
  
  close(data)

  if(G["doupload"])
      upload(readfile(data), "Data:Wikipedia statistics/exturls.tab", "Update statistics", G["home"] "log", BotName, "commons", "wikimedia")

}

#
# Number of pages in NS 0 & 6
#
function pagesF(site,  command,out) {

  command = Exe["wget"] " -q -O- --user-agent=" shquote(Agent) " " shquote("https://" site "/w/api.php?action=query&meta=siteinfo&siprop=statistics&format=json") " | jq -r '.query.statistics.articles + .query.statistics.images' "
  out = sys2var(command)
  if(empty(out))
    return "0"
  return out
}

#
# Number of archive.org/details links
#
function ialiburlsF(site,  command,out) {

  gsub("-", "_", site)

  if(!checkexists("adn.com." site)) 
    return "0 0 0"

  # This will filter out duplicates caused by two+ URLs in the same cite: one for base URL + one or more for page number URLs
  # All URLs with a page number are counted even if duplicate. 
  # If a base URL exists that matches any of the page URLs it is not counted
  # If a base URL exists without any page URLs it is counted.
  # Note: optimized for speed and memory use

  # Manual command: -v verbose=1 to print the URLs to the screen, verbose=0 print only summary results
  # echo 'etwiki' | awk '{print "adn.com." $0}' | xargs awk -v re='^(0|6)$' -v verbose=0 -ilibrary 'BEGINFILE{if(ERRNO) nextfile } BEGIN { real_count = 0; } {c = split($0, a, " "); if(c == 3) {ns = strip($2); if(ns ~ re) {if($3 ~ /\/\/(org[.]archive(([.]us)?[.]www([0-9]{1,3})?)?[.]\/(stream|details)\/)/) { full_url = $3; base = full_url; sub(/\/page\/.*$/, "", base); sub(/#page\/.*$/, "", base); article_key = $1 ":" base; sub(/^http:/, "https:", full_url); if(full_url ~ /\/page\/|#page\//) { has_page[article_key] = 1; tracked_urls[full_url] = 1; if(verbose == 1) { print $0; } real_count++; articles[$1] = 1; } else { base_lines[article_key] = $0; base_urls[article_key] = full_url; } } } } } END{ for(article_key in base_lines) { if(has_page[article_key] != 1) { if(verbose == 1) { print base_lines[article_key]; } real_count++; url = base_urls[article_key]; tracked_urls[url] = 1; split(base_lines[article_key], fields, " "); articles[fields[1]] = 1; } } print real_count " " length(tracked_urls) " " length(articles); }'"

  command = "echo " shquote(site) " | awk '{print \"adn.com.\" $0}' | xargs awk -v re='^(0|6)$' -v verbose=0 -ilibrary 'BEGINFILE{if(ERRNO) nextfile } BEGIN { real_count = 0; } {c = split($0, a, \" \"); if(c == 3) {ns = strip($2); if(ns ~ re) {if($3 ~ /\\/\\/(org[.]archive(([.]us)?[.]www([0-9]{1,3})?)?[.]\\/(stream|details)\\/)/) { full_url = $3; base = full_url; sub(/\\/page\\/.*$/, \"\", base); sub(/#page\\/.*$/, \"\", base); article_key = $1 \":\" base; sub(/^http:/, \"https:\", full_url); if(full_url ~ /\\/page\\/|#page\\//) { has_page[article_key] = 1; tracked_urls[full_url] = 1; if(verbose == 1) { print $0; } real_count++; articles[$1] = 1; } else { base_lines[article_key] = $0; base_urls[article_key] = full_url; } } } } } END{ for(article_key in base_lines) { if(has_page[article_key] != 1) { if(verbose == 1) { print base_lines[article_key]; } real_count++; url = base_urls[article_key]; tracked_urls[url] = 1; split(base_lines[article_key], fields, \" \"); articles[fields[1]] = 1; } } print real_count \" \" length(tracked_urls) \" \" length(articles); }'"

  out = sys2var(command)

  if(empty(out))
    return "0 0 0"
  return out


}

#
# Number of urls excluding archive URLs
#
function urlsF(site,  command,out) {

  gsub("-", "_", site)

  if(!checkexists("adn.com." site)) 
    return "0 0 0"

  command = "echo " shquote(site) " | awk '{print \"adn.com.\" $0}' | xargs awk -v re='^(0|6)$' -ilibrary 'BEGINFILE{if(ERRNO) nextfile } BEGIN { Count=0; } {c = split($0, a, \" \"); if(c == 3) {ns = strip($2); if(ns ~ re) {if($3 !~ /\\/\\/(org[.]archive[.]\\/web|org[.]archive[.]web[.]\\/|(is|today|ph|fo|li|vn|md)[.]archive[.]\\/|org[.]webcitation[.]www[.?])/) { Count++; url=$3; sub(/^http:/, \"https:\", url); U[url] = 1; P[$1] = 1 } } } }END{if(Count > 0) print Count \" \" length(U) \" \" length(P) }'"

  out = sys2var(command)

  if(empty(out))
    return "0 0 0"
  return out

}

#
# Number of Wayback urls 
#
function waybackurlsF(site,  command,out) {

  gsub("-", "_", site)

  if(!checkexists("adn.com." site)) 
    return "0 0 0"

  command = "echo " shquote(site) " | awk '{print \"adn.com.\" $0}' | xargs awk -v re='^(0|6)$' -ilibrary 'BEGINFILE{if(ERRNO) nextfile } BEGIN {Count=0;} {c = split($0, a, \" \"); if(c == 3) {ns = strip($2); if(ns ~ re) {if($3 ~ /\\/\\/(org[.]archive[.]\\/web|org[.]archive[.]web[.]\\/)/) { Count++; url=$3; sub(/^http:/, \"https:\", url); U[url] = 1; P[$1] = 1 } } } }END{if(Count > 0) print Count \" \" length(U) \" \" length(P) }'"

  out = sys2var(command)

  if(empty(out))
    return "0 0 0"
  return out

}

#
# Number of Archive.today urls 
#
function archivetodayurlsF(site,  command,out) {

  gsub("-", "_", site)

  if(!checkexists("adn.com." site)) 
    return "0 0 0"

  command = "echo " shquote(site) " | awk '{print \"adn.com.\" $0}' | xargs awk -v re='^(0|6)$' -ilibrary 'BEGINFILE{if(ERRNO) nextfile } BEGIN {Count=0;} {c = split($0, a, \" \"); if(c == 3) {ns = strip($2); if(ns ~ re) {if($3 ~ /\\/\\/(is|today|ph|fo|li|vn|md)[.]archive[.]\\//) { Count++; url=$3; sub(/^http:/, \"https:\", url); U[url] = 1; P[$1] = 1 } } } }END{if(Count > 0) print Count \" \" length(U) \" \" length(P) }'"

  out = sys2var(command)

  if(empty(out))
    return "0 0 0"
  return out

}

#
# Number of WebCite urls 
#
function webciteurlsF(site,  command,out) {

  gsub("-", "_", site)

  if(!checkexists("adn.com." site)) 
    return "0 0 0"

  command = "echo " shquote(site) " | awk '{print \"adn.com.\" $0}' | xargs awk -v re='^(0|6)$' -ilibrary 'BEGINFILE{if(ERRNO) nextfile } BEGIN {Count=0;} {c = split($0, a, \" \"); if(c == 3) {ns = strip($2); if(ns ~ re) {if($3 ~ /\\/\\/org[.]webcitation[.]www[.]/) { Count++; url=$3; sub(/^http:/, \"https:\", url); U[url] = 1; P[$1] = 1 } } } }END{if(Count > 0) print Count \" \" length(U) \" \" length(P) }'"

  out = sys2var(command)

  if(empty(out))
    return "0 0 0"
  return out

}

