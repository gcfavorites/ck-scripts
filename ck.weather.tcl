
encoding system utf-8
::ck::require cmd 0.6
::ck::require cache
::ck::require http
::ck::require strings 0.3

namespace eval ::weather {
  variable version 1.1
  variable author "Chpock <chpock@gmail.com>"
  variable editor "kns@RusNet"

  namespace import -force ::ck::cmd::*
  namespace import -force ::ck::http::http
  namespace import -force ::ck::cache::cache
}

proc ::weather::init {  } {

  datafile register weather.alias
  datafile register weather.citys

  cache register -ttl 3h -maxrec 30

  cmd doc -link "weather.alias" "weather" \
    {~*!weather* [-день] <город>~ - подробная погода на <день> относительно текущего дня.}
  cmd doc -link "weather" "weather.alias" \
    {~*!weather* <псевдоним> = <город>~ - добавление псевдонима для города <город>.}

  cmd register weather ::weather::run -autousage -doc "weather" \
    -bind "weather" -bind "погода" -force-prefix -bind "w" -bind "п"

  config register -id "admflags" -type str -default "m" \
    -desc "Flags for access to change weather aliases." -access "n" -folder "weather"
  config register -id "updflags" -type str -default "n" \
    -desc "Требуемые флаги для обновление базы городов." -access "n" -folder "weather"

  msgreg {
    nocity        &RГород по Вашему запросу не найден.
    manymatch     &RУточните запрос. По Вашему запросу найдены города&K: &B%s
    manymatchj    "&K, &B"
    day0          &b%s &p%s &bв городе &r%s &g%s
    day           &r(&p%1$s&r)&b &g%4$s
    temp          %s..%s°C
    press         &bдавление&p %s &bмм рт/с
    wind          &bветер &p%s&g %s..%s&b м/с
    relw          &bвлажность &p%s&b%%
    env           &g%s
    day.join      "&n, "
    join          " &K// "
    main          %s&n.

    alias.remove  &BУдален(ы) псевдоним(ы):&R %s
    alias.removej "&K, &R"
    alias.add     &BДобавлен псевдоним &K<&r%s&K>&B как синоним &K<&R%s&K>&B.

    err.parse     &RОшибка получения данных о погоде в &Bг.%s
    err.nodata    &cНет данных о погоде в &Bг.%s&c на запрашиваемый период.
    err.noalias   &RПсевдонимы по маске &K<&B%s&K>&R не найдены.

    upd.try       &BПытаюсь обновить базу данных городов для погоды...
    err.upd.http  &RОшибка связи с сервером.
    err.upd.pars  &RОшибка разбора данных полученных от сервера.
    upd.done      &BОбновление успешно завершено. В базе &R%s&B городов.
    err.needupd   &RБаза городов пуста, пожалуйста сделайте&B !weather update&R.
  }
}

proc ::weather::run { sid } {
  session import

  if { $Event eq "CmdPass" } {
    set Request [join [lrange $StdArgs 1 end] { }]
    if { [regexp {^([^=]+?)\s*=\s*(.*)$} $Request - als trg] } {
      session insert CmdAccess [config get "admflags"]
      checkaccess -return
      set als [string trim $als]
      if { [set trg [string trim $trg]] eq "" } {
	set lals [list]
	set rmals [list]
	foreach_ [datafile getlist weather.alias] {
	  if { [string match -nocase $als [lindex_ 0]] } {
	    lappend rmals [lindex_ 0]
	  } {
	    lappend lals $_
	  }
	}
	if { ![llength $rmals] } { reply -err noalias $als }
	datafile putlist weather.alias $lals
	reply -return alias.remove [cjoin $rmals alias.removej]
      }
      set lals [list]
      foreach_ [datafile getlist weather.alias] {
	if { ![string equal -nocase [lindex_ 0] $als] } { lappend lals $_ }
      }
      lappend lals [list $als $trg]
      datafile putlist weather.alias $lals
      reply -return alias.add $als $trg
    }
    if { [string equal -nocase $Request "update"] } {
      session insert CmdAccess [config get "updflags"]
      checkaccess -return
      session hook default ::weather::update
      update $sid
      return
    }
    if { [regexp {[+-](\d)} $Request - WeatherOffset] } {
      regfilter {[+-]\d} Request
      set Request [string trim $Request]
    } {
      set WeatherOffset 0
    }
    session insert WeatherOffset $WeatherOffset
    array set {} [searchcity $Request]
    if { $(size) < 10 } {
      reply -err needupd
    } elseif { ![llength $(city)] } {
      reply -err nocity
    } elseif { [llength $(city)] > 1 } {
      reply -err manymatch [cjoin $(city) manymatchj]
    }
    debug -debug "Try to get weather for city <%s\(%s\)>" [lindex $(city) 0] [lindex $(num) 0]
    session insert CityName [lindex $(city) 0]
    weather [lindex $(num) 0]
    return
  }

  if { $WeatherStatus < 0 } { reply -err parse $CityName }
#  debug "WeatherData1: $WeatherData"
  set WeatherData [filt $WeatherOffset $WeatherData]
#  debug "WeatherData2: $WeatherData"
  if { ![llength $WeatherData] } { reply -err nodata $CityName }

  set data [list]
  foreach_ $WeatherData {
    array set {} $_

    set_ [list [lindex {ясно малооблачно облачно пасмурно} $(Cloud)]]
    switch -- $(Precip) {
      4 { lappend_ "дождь" }
      5 { lappend_ "ливень" }
      6 - 7 { lappend_ "снег" }
      8 { lappend_ "гроза" }
    }
    set x [join_ {, }]
    if { $(Hour) >= 0 && $(Hour) <= 4 } { set_ "Ночью"
    } elseif { $(Hour) >= 5 && $(Hour) <= 10 } { set_ "Утром"
    } elseif { $(Hour) >= 11 && $(Hour) <= 17 } { set_ "Днем"
    } else { set_ "Вечером" }
    set frm day; if { ![llength $data] } { append frm 0 }
    set out [list   [cformat $frm \
                        $_ \
                        [lindex \
                            [list "воскресенья" "понедельника" "вторника" "среды" \
                                    "четверга" "пятницы" "субботы" "воскресенья" \
                            ] \
                            [clock format [clock scan "$(Month)/$(Day)/$(Year)"] -format %u] \
                        ] \
                        $CityName \
	                    [cformat temp $(MinT) $(MaxT)] \
                    ] \
            ]

# $x - не забыть. облачно//

    lappend out [cformat press [~ $(MinP) $(MaxP)]]

    lappend out [cformat wind \
                    [lindex \
                        [list   "северный" "северный" \
                                "северо-восточный" "северо-восточный" \
                                "восточный" "восточный" \
                                "юго-восточный" "юго-восточный" \
                                "южный" "южный" "юго-западный" \
                                "западный" "западный" "западный" \
                                "северо-западный" "северо-западный" \
                        ] \
                    $(RumbW)] \
                    $(MinW) $(MaxW) \
                ]
    lappend out [cformat relw [~ $(MinRW) $(MaxRW)]]
    lappend out [cformat env $x]
    lappend data [cjoin $out "day.join"]
  }
  reply -noperson -uniq -multi main [cjoin $data join]
}
proc ::weather::searchcity { str } {
  set (city) [list]
  set (num)  [list]
  set str [string tolower $str]
  foreach_ [datafile getlist weather.alias] {
    if { [lindex_ 0] == $str } { set lstr [list [lindex_ 1]]; break }
  }
  if { ![info exists lstr] } {
    set lstr [list [string trans2rus $str]]
  }
  set (size) [llength [set base [datafile getlist weather.citys]]]
  foreach_ $base {
    foreach str $lstr {
      if { [string match -nocase $str [lindex_ 0]] } {
	lappend (city) [lindex_ 0]
	lappend (num) [lindex_ 1]
      }
    }
    if { [llength $(city)] > 20 } break
  }
  return [array get {}]
}
proc ::weather::update { sid } {
  session import
  if { $Event eq "CmdPass" } {
    reply upd.try
    http run "http://gen.gismeteo.ru/frcdb/cityinfr.txt" -return -charset "cp866"
  }
  if { $HttpStatus < 0 } {
    reply -err upd.http
  }
  set datalist [list]
  foreach_ [split $HttpData "\n"] {
    set_ [string trim $_]
    if { $_ eq "" } continue
    if { ![regexp {^[0-9-]+\s+([0-9-]{5})\s+[0-9-]+\s+[0-9-]+\s+(.+)$} $_ - n g] } {
      reply -err upd.pars
    }
    lappend datalist [list $g $n]
  }
  reply upd.done [llength $datalist]
  datafile putlist weather.citys $datalist
}
proc ::weather::weather { citynum } {
  upvar sid sid
  session create -child -proc ::weather::weather_request \
    -parent-event WeatherResponse
  session export \
    -grab citynum as RequestCityNum
  session parent
  return
}
proc ::weather::weather_request { sid } {
  session import

  if { $Event eq "SessionInit" } {
    cache makeid $RequestCityNum
    if { ![cache get HttpData] } {
      http run "http://informer.gismeteo.ru/xml/${RequestCityNum}_1.xml" -return
    }
  } elseif { $Event eq "HttpResponse" } {
    if { $HttpStatus < 0 } {
      debug -err "while http request."
      session return WeatherStatus -99 WeatherError "while http request."
    }
    cache put $HttpData
  }

  array set result [list]
  
#  debug "HttpData: %s" $HttpData
  
  foreach [list _ \
  				Day Month Year Hour \
  				Cloud Precip MaxP MinP \
  				MaxT MinT MinW MaxW \
  				RumbW MaxRW MinRW MinHT MaxHT] \
  			 [regexp -all -inline -- \
  			 		{<FORECAST day="([^\"]+)" month="([^\"]+)" year="([^\"]+)" hour="([^\"]+)"[^>]*>\s*<PHENOMENA cloudiness="([^\"]+)" precipitation="([^\"]+)"[^>]*>\s*<PRESSURE max="([^\"]+)" min="([^\"]+)"/>\s*<TEMPERATURE max="([^\"]+)" min="([^\"]+)"/>\s*<WIND min="([^\"]+)" max="([^\"]+)" direction="([^\"]+)"/>\s*<RELWET max="([^\"]+)" min="([^\"]+)"/>\s*<HEAT min="([^\"]+)" max="([^\"]+)"/>\s*</FORECAST>} \
  			 	$HttpData] {
  				
		debug -raw "data: %s" "$Day $Month $Year $Hour $Cloud $Precip $MaxP $MinP $MaxT $MinT $MinW $MaxW $RumbW $MaxRW $MinRW $MinHT $MaxHT"


		array set {} [list]
		foreach _ [list \
  							Day Month Year Hour \
  							Cloud Precip MaxP MinP \
  							MaxT MinT MinW MaxW \
  							RumbW MaxRW MinRW MinHT MaxHT \
  					  ] {
  			set ($_) [set $_]
  		}
  		
  		set id "$(Year)[0 $(Month)][0 $(Day)][0 $(Hour)]"
  		set result($id) [array get {}]
  		unset {}
  }
  
  if { ![array size result] } {
    debug -err "while parsing data:"
    foreach_ [split $HttpData \n] {
      if { ![string length $_] } continue
      debug -err- "  > %s" $_
    }
    session return WeatherStatus -50 WeatherError "while parsing data."
  }

  session return WeatherStatus 0 WeatherError "" WeatherData [array get result]
}
proc ::weather::filt { offset data } {
  set result [list]
  set last 0
  array set {} $data
  foreach_ [lsort -integer [array names {}]] {
    if { !$last } { set last $_ }
    if { $offset } {
      if { [string equal -length 8 $_ $last] } continue
      set last $_
      if { [incr offset -1] } continue
    }
    if { ![string equal -length 8 $_ $last] } break
    lappend result $($_)
  }
  return $result
}
proc ::weather::0 a { if { [string length $a] == 1 } { return "0$a" } { return $a } }
proc ::weather::~ {1 2} { return [expr { int(.5 * ($1 + $2)) }] }

::weather::init
