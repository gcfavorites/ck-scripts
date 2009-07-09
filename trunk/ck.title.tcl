encoding system utf-8

::ck::require cmd 0.10
::ck::require http 0.5
::ck::require strings

namespace eval ::gettitle {
    variable version 0.9
    variable author  "kns @ RusNet"

# переменная, в которой будут храниться игноры
    variable tignores [list]

    variable lasturl [list 0 0]

    namespace import -force ::ck::cmd::*
    namespace import -force ::ck::http::http
    namespace import -force ::ck::strings::html
}


proc ::gettitle::init {  } {
    variable tignores

# регистрируем новый datafile для списка игноров
    datafile register tignores -net -bot


#++ cmds
    cmd register gettitle [namespace current]::run -doc "gettitle" -autousage \
        -bindpub "title" -bindpub "gettitle"

    cmd register gettitleignore [namespace current]::ignore -doc "gettitle.ignore" -autousage \
        -bindpub "tignore" -config "gettitle" -access "m"

    cmd register gettitleunignore [namespace current]::ignore -doc "gettitle.unignore" -autousage \
        -bindpub "tunignore" -config "gettitle" -access "m"

    cmd register gettitlesearch [namespace current]::ignore -doc "gettitle.search" -autousage \
        -bindpub "tsearch" -config "gettitle" -access "m"

    cmd register gettitlelist [namespace current]::ignore -doc "gettitle.list" \
        -bindpub "tlist" -config "gettitle" -access "m"


    cmd regfilter gettitle [namespace current]::filter -cmd "gettitle" \
        -pub -prio 100
#-- cmds

#++ docs
    cmd doc -link [list "gettitle.ignore" "gettitle.unignore" "gettitle.search" "gettitle.list"] \
        "gettitle" {~*!title* <url>~ - получение заголовка странички.}

    cmd doc -link [list "gettitle" "gettitle.unignore" "gettitle.search" "gettitle.list"] \
        "gettitle.ignore" {~*!tignore* <url>~ - добавить сайт в список игнорируемых (можно использовать маски).}

    cmd doc -link [list "gettitle" "gettitle.ignore" "gettitle.search" "gettitle.list"] \
        "gettitle.unignore" {~*!tunignore* <url>~ - удалить сайт из списка игнорируемых (можно использовать маски).}

    cmd doc -link [list "gettitle" "gettitle.ignore" "gettitle.unignore" "gettitle.list"] \
        "gettitle.search" {~*!tsearch* <домен/шаблон>~ - поиск в списке игноров.}

    cmd doc -link [list "gettitle" "gettitle.ignore" "gettitle.unignore" "gettitle.search"] \
         "gettitle.list" {~*!tlist*~ - показать список игноров.}
#-- docs

#++ configs
    config register -id "auto" -type bool -default 1 \
        -desc "Автоматически выхватывать ссылки из сообщений на каналах" -access "n" \
        -folder "gettitle"

    config register -id "forceonchans" -type list -default [list] \
        -desc "Форсировать автоматическую обработку сообщений в канале." -access "n" \
        -folder "gettitle" -disableon [list "auto" 1]

    config register -id "denpr" -type list \
        -default [list "!" "\$" "%" "&" "." "-" "@" "*" "+" "~" "`" "\?"] \
        -desc "Префиксы команд, сообщения с ними обрабатываться не будут" -access "n" \
        -folder "gettitle"

    config register -id "alltypes" -type list \
        -default    [list   "text/html" "text/wml" "text/vnd.wap.wml" \
                            "text/xml" "application/xml" "application/rss+xml" \
                    ] \
        -desc "Разрешенные Content-Type. маски не поддерживаются (а, может быть, поддерживаются :)))" \
        -access "n" -folder "gettitle"

    config register -id "ignore" -type str -default "I|-" \
        -desc "Флаг для игнорируемых юзеров." -access "n" -folder "gettitle"

    config register -id "infostr" -type str -default "URL title" \
        -desc "Слово/словосочетание, с которого будет начинаться строка вывода." -access "n" -folder "gettitle"

    config register -id "maxlen" -type int -default 200 \
        -desc "Максимальная длина выводимого заголовка" -access "n" -folder "gettitle"

    config register -id "maxsredirs" -type int -default 5 \
        -desc "Максимальное число редиректов (заголовки 301,302)" -access "n" \
        -folder "gettitle"

    config register -id "maxmredirs" -type int -default 3 \
        -desc "Максимальное число meta-редиректов (meta refresh)" -access "n" \
        -folder "gettitle"

    config register -id "readlimit" -type int -default 11264 \
        -desc "Максимальное число загружаемых байтов" -access "n" -folder "gettitle"

    config register -id "showredirscount" -type bool -default 0 \
        -desc "Показывать кол-во выполненных редиректов" -access "n" -folder "gettitle"

    config register -id "showsize" -type bool -default 0 \
        -desc "Показывать размер файла (пока сделано только для изображений)" -access "n" \
        -folder "gettitle"

    config register -id "showspeed" -type bool -default 0 \
        -desc "Показывать скорость получения ссылки" -access "n" -folder "gettitle"

    config register -id "useragent" -type str -default "Opera/9.80 (Windows NT 5.1; U; en) Presto/2.2.15 Version/10.00" \
        -desc "User Agent" -access "n" -folder "gettitle"
#-- configs


    set tignores [datafile getlist tignores]

    msgreg {
        err.badurl      эта строка не похожа на ссылку

        main.inf        &L&p%s&L%s&n: %s %s
        main.time       " &K(&g%s %s&K)"
        main.debug      &K[&g%s&K]&n
        main.url        &K<&B%s&K>&n
        main.add        %s - %s

        size.bytes      &g%s&n %s
        size.kbytes     &r%s&n %s
        size.mbytes     &R%s&n %s

        dbg             Возможно неправильное определение кодировки (%s), пробуем %s
        mtype           [%s]

        exists          &K<&R%s&K>&n уже в списке игнорирования &K(&g%s&K)&n
        notexists       &K<&R%s&K>&n не найден в списке игнорирования

        add             &K<&R%s&K>&n добавлен в список игнорирования
        del             &K<&R%s&K>&n удален из списка игнорирования

        found           &K<&R%s&K>&n найден в списке игнорирования &K(&g%s&K)&n
        notfound        &K<&R%s&K>&n не найден в списке игнорирования

        ignores         список игнорирования: &R%s&n.
        join.ignores    "&K,&R "
        join.add        " &K::&R "
        join.dim        "x"
        join.all        " % "
    }
}

#++ seturl
## Выдергивает ссылку из строки
proc ::gettitle::seturl {ustr} {

    set end [list   "\"" "'" "`" "," ";" "#" \
                    "\\s" "\\\\" "\\(" "\\)" "\\\[" "\\\]" "\\\{" "\\\}" \
                    "\017" "\026" \
            ]

    set end [join $end ""]
    set ustr [stripcodes bcruag $ustr]
    set url ""

    if {[regexp -nocase -- "(http://\[^${end}\]+).*" $ustr -> url] \
            || [regexp -nocase -- "(w(?:ap|ww)\\.\[^${end}\]+).*" $ustr -> url]} {
        set url [string trimright $url "."]

        unset ->
    }

    unset end

    return $url
}
#-- seturl

proc ::gettitle::filter { } {
    foreach_ {Text Nick UserHost Handle Channel CmdDCC CmdEvent} { upvar $_ $_ }

    if {![config get auto] \
            && ![llength [lfilter -keep -nocase -- [config get forceonchans] $Channel]]} {
#        debug -debug "automode disabled"
        return
    }

    set url ""
    set ign [config get ignore]
    set binds [binds [lindex [split $Text] 0]]

    if {([lsearch [config get denpr] [string index $Text 0]] == -1) \
            && ![llength $binds] \
            && ([string match {*[a-zA-Z]*} $ign] \
                    && ![matchattr $Handle $ign $Channel]) \
            && ([set url [seturl $Text]] ne "")} {

#        debug -debug $url
        set Text ""

        ::ck::cmd::prossed_cmd $CmdEvent $Nick $UserHost $Handle $Channel \
                                    "title $url" gettitle $CmdDCC FilterMark
    }

    unset url ign binds

    return
}


proc ::gettitle::run { sid } {
    session import

    if { $Event eq "CmdPass"  } {
        set url [lindex $StdArgs 1]

        if {[string first "." $url] < 1 || [string length $url] < 4} {
            if {$CmdEventMark eq ""} { reply -err badurl }
        }

        variable lasturl

        if {[lindex $lasturl 0] eq $url \
                && [expr {[clock seconds] - [lindex $lasturl 1]}] < 10} {
            set lasturl [list $url [clock seconds]]
            debug -debug "too many requests"
            if {$CmdEventMark eq ""} { reply -err "слишком частые запросы" }
            return 0
        }
        set lasturl [list $url [clock seconds]]

        variable tignores

        if {$CmdEventMark eq "FilterMark" && [llength $tignores]} {

            regexp -- {^(?:https?://)?(?:w(?:ap|ww)\.)?([^/\?:]+)} $url -> dom
#            debug "Домен: $dom"


            set i ""
            set_ ""
            foreach_ $tignores {
                if {[string match -nocase $_ $dom]} {
                    set i $_
                    break
                }
            }

            if {$i ne ""} {
                debug -err [regsub -all -- {\&[a-zA-Z]} [::ck::cmd::stripMAGIC [cformat found $dom $i]] ""]
                return
            }
            unset _ i dom
        }

        session set StartGet [clock clicks]; # пускаем счетчик
        session set MetaRedirs 0

        http run $url \
            -mark "Get" \
            -norecode \
            -readlimit [config get readlimit] \
            -redirects [config get maxsredirs] \
            -useragent [config get useragent]

        unset url
        return
    }

    if { $Mark eq "Get" } {
        set GetTime [clock clicks]; # замеряем время получения

        if { $HttpStatus < 0 } {
            debug -err "Ошибка запроса '%s'." $HttpError
            if {$CmdEventMark eq ""} { reply -err "Ошибка запроса: '%s'." $HttpError }
            return
        }

#        debug -debug "GetTime: %0.3f ms" [expr {($GetTime - $StartGet) / 1000.0}]

#        debug $HttpUrl

        if {([lsearch [config get alltypes] $HttpMetaType] != -1)} {

#++ <head></head>
            if {[regsub -nocase {<head>(.+)$} $HttpData {\1} HttpHead]} {
                regsub -nocase {</head>.*$} $HttpHead "" HttpHead

                session set HttpHead $HttpHead

#                debug $HttpHead

                if {([set url [catch_refresh $sid]] ne "") \
                        && ($MetaRedirs < [config get maxmredirs])} {

                    set cookie [list]
                    foreach_ $HttpMetaCookie {
                        foreachkv $_ {lappend cookie $k $v; unset k v}
                    }

                    http run $url \
                        -mark "Get" \
                        -norecode \
                        -readlimit [config get readlimit] \
                        -redirects 2 \
                        -useragent [config get useragent] \
                        -heads [list "Referer" $HttpUrl] \
                        -cookpack $cookie
                    session set MetaRedirs [incr MetaRedirs]
                    unset cookie
                    return
                } else {
                    debug -debug "No redirects; working with a full page"
                    session set HttpHead $HttpData
                }
            } else {
                debug -debug "Headers are not found; working with a full page"
                session set HttpHead $HttpData
            }
#--

            set title [string stripspace [html unspec [html untag [get_title $sid]]]]

            set maxlen [config get maxlen]

            if {$title ne ""} {
                debug -debug- "title: $title"

                if {[string length $title] > ${maxlen}} {
                    set title [string trimright [string range $title 0 [expr ${maxlen}-3]] ". ,:;¤-"]
                    append title "..."
                }

                session set EndGet [clock clicks]; #останавливаем счетчик
                set GTime ""
                stop_counter $sid

                if {[config get showredirscount] || $CmdEventMark eq ""} {
                    set dinfo [list]
                    lappend dinfo [cformat "main.add" "S" $HttpRedirCount]
                    lappend dinfo [cformat "main.add" "M" $MetaRedirs]
                    set redirs [cformat "main.debug" [cjoin $dinfo "join.add"]]
                    unset dinfo
                } else {
                    set redirs ""
                }

                reply -noperson -uniq "main.inf" [config get infostr] $GTime [cformat "main.url" $title] $redirs
            } else {
                debug -debug "Title is empty"
                if {$CmdEventMark eq ""} { reply -err "ошибка: пустой заголовок"}
            }

            unset maxlen title

        } elseif {[config get showsize] || ($CmdEventMark eq "")} {
            debug -debug "Trying to get file size"

            switch -glob -- [string tolower $HttpMetaType] {
                "image/*"                   {set type "Image"}
                "audio/*"                   {set type "Audio"}
                "video/*"                   {set type "Video"}
                "application/*zip*"                 -
                "application/*compress*"            -
                "application/*tar*"                 -
                "application/*rar*"         {set type "Archive"}
                "application/*program*"     {set type "Program"}
                default {
                    debug -debug "Unknown 'Content-Type': '%s'" $HttpMetaType
                    if {$CmdEventMark eq ""} { reply -err "ошибка: тип '%s' отсутствует в списке разрешенных" $HttpMetaType}
                    return 1
                }
            }

            if {[string is digit $HttpMetaLength] && ($HttpMetaLength > 0)} {
#                debug -debug "Original size: %s" $HttpMetaLength

                set repl [list]

#++ size
                lappend repl [cformat "main.add" "Size" [cjoin [format_size $sid] "join.add"]]
#-- size

#++ extra
                set extra [get_dimensions $HttpData [lindex [split $HttpMetaType "/"] end]]
                if {$type eq "Image" && [llength $extra]} {
                    lappend repl [cformat "main.add" [cjoin [list "W" "H"] "join.dim"] [cjoin $extra "join.dim"]]
                }
                unset extra
#-- extra

#++ mtype
#                lappend repl [cformat "main.add" "Type" [cformat "mtype" [get_type $type $HttpMetaType]]]
                lappend repl    [cformat "main.add" "Type" \
                                    [cformat "mtype" \
                                        [lindex [split $HttpMetaType "/"] end] \
                                    ] \
                                ]
#-- mtype

                set repl [cjoin $repl "join.all"]

                session set EndGet [clock clicks]; #останавливаем счетчик
                set GTime ""
                stop_counter $sid

                reply -noperson -uniq "main.inf" $type $GTime $repl ""

                unset GTime type repl
            }  else {
                debug -debug "Empty 'Content-Length'"
                if {$CmdEventMark eq ""} { reply -err "ошибка: размер файла неизвестен" }
            }
        } else {
            debug -debug "Unknown 'Content-Type': '%s'" $HttpMetaType
            if {$CmdEventMark eq ""} { reply -err "ошибка: тип '%s' отсутствует в списке разрешенных" $HttpMetaType}
        }
    }

    return
}

proc ::gettitle::ignore { sid } {
    session import

    if { $Event eq "CmdPass"  } {
        variable tignores

        set Text [lindex $StdArgs 1]

        set i ""
        set_ ""

        foreach_ $tignores {
            if {[string match -nocase $Text $_] \
                    || [string match -nocase $_ $Text]} {
                set i $_
                break
            }
        }

        switch -exact -- $CmdId {
            "gettitleignore" {
                if {$i eq ""} {
                    lappend tignores $Text
                    datafile putlist tignores $tignores

                    reply add $Text
                } else {
                    reply exists $Text $i
                }
            }

            "gettitleunignore" {
                if {$i eq ""} {
                    reply notexists $Text
                } else {
                    set nignores [list]
                    foreach_ $tignores {
                        if {[string match -nocase $Text $_]} { continue }

                        lappend nignores $_
                    }

                    set tignores $nignores
                    datafile putlist tignores $tignores
                    reply del $Text

                    unset nignores
                }
            }

            "gettitlesearch" {
                if {$i eq ""} {
                    reply notfound $Text
                } else {
                    reply found $Text $i
                }
            }

            "gettitlelist" {
                if {![llength $tignores]} {
                    set_ "пуст"
                } else {
                    set_ [cjoin $tignores "join.ignores"]
                }

                if {[string length $_] > 225} {
                    session set CmdReplyParam [list "-private" "-multi" "-multi-max" "-1" "-return"]
                }
                reply ignores $_
            }
        }
        unset _ i
    }

    return
}

#++ get_cp
## Выдергивает кодировку из html-кода
proc ::gettitle::get_cp {data metacp} {
    if {![regexp -nocase -- {<meta[^>]+charset\s*=\s*([^\s\"\'>]+).*?>} $data -> cp] \
            && ![regexp -nocase -- {<?xml\s+version[^>]+encoding="([^\s\'\/\>]+)"} $data -> cp]} {

        set cp $metacp
        debug -debug- "set cp \$metacp"
    } else {unset ->}

    set ret [::ck::http::charset2encoding $cp]

    if {$ret eq "binary"} {
        set ret "cp1251"
#        set ret $::ck::ircencoding
    }

    debug -debug- "MetaCp: '%s' %% RawCp: '%s' %% Ret: '%s'" $metacp $cp $ret

    unset cp

    return $ret
}
#-- get_cp

#++ check_cp
## Попытка проверки правильности выбранной кодировки
proc ::gettitle::check_cp {title} {

    upvar cp cp

    set cyrtitle [encoding convertfrom $cp $title]

    debug -debug "String in the detected cp: '%s'" $cyrtitle
    debug -debug- "Trying to verify the codepage"

    regsub -all -- {[^а-яА-ЯёЁ]} $cyrtitle "" cyrtitle
    debug -debug- "Cyrillic part of the line: %s" $cyrtitle

    set frmt "Возможно неправильное определение кодировки (%s), пробуем %s"
    set strlen [string length $cyrtitle]

    switch -exact -- $cp {
        "cp1251" {
            set strtmp [regexp -all -- {[РС]} $cyrtitle]
            set mctitle [string range $cyrtitle 0 4]
            set mctitle_ [string tolower [string index $mctitle 0]]
            append mctitle_ [string toupper [string range $mctitle 1 end]]

            if {([string length $mctitle] > 4) && ($mctitle eq ${mctitle_})} {
                debug -debug [format $frmt $cp "koi8-r"]
                set cp "koi8-r"
            } elseif {$strlen > 18 && [expr {1.0 * $strtmp / $strlen}] > 0.28} {
                debug -debug [format $frmt $cp "utf-8"]
                set cp "utf-8"
            }

            unset strtmp mctitle mctitle_
        }

        "koi8-r" {
            set strtmp [regexp -all -- {[пя]} $cyrtitle]
            if {$strlen > 18 && [expr {1.0 * $strtmp / $strlen}] > 0.28} {
                debug -debug [format $frmt $cp "utf-8"]
                set cp "utf-8"
            }

            unset strtmp
        }
    }

    unset strlen cyrtitle

    return 1
}
#-- check_cp

proc ::gettitle::get_title { sid } {
    session import

    set data $HttpHead
    set metacp $HttpMetaCharset

    set ret ""

    if {![regexp -nocase -- {<title[^>]*>(.+?)$} [regsub -nocase -- {</title>.*$} $data ""] -> title] \
            && ![regexp -nocase -- {<meta[^>]+name="title"[^>]+content="([^\"]+)"} $data -> title] \
            && ![regexp -nocase -- {<card[^>]+title="([^\"]+)"} $data -> title]} {
        debug -err "Title not found"
    } else {
        debug -debug "rawtitle: \"$title\""

        set cp [get_cp $data $metacp]
        check_cp $title; # Попытка выправить кодировку

        set ret [encoding convertfrom $cp $title]

        unset -> title
    }

    unset data

    return $ret
}

proc ::gettitle::get_url { HttpUrl v } {

#++ ripped from ck.http
    if {[regexp -nocase -- {^https?://} $v]} {
        set HttpMetaLocation $v
    } elseif {[string index $v 0] eq "/"} {
        regexp -nocase -- {^((?:https?://)?[^/\?]+)} $HttpUrl -> url
        set HttpMetaLocation "${url}${v}"
    } else {
        set url [join [lrange [split $HttpUrl "/"] 0 end-1] "/"]
        set HttpMetaLocation "${url}/${v}"
    }
#--
    return $HttpMetaLocation
}

proc ::gettitle::catch_refresh { sid } {
    session import

    if {[regexp -- {<meta http-equiv=[\"\']?refresh[\"\']?([^>]+)>} [string tolower $HttpHead] -> meta] \
            && [regexp -- {content=[\"\']([0-9\.]+)[\s\;]*(?:url=)?([^\"\']+)?} $meta -> time url]} {
        debug -debug "Time: %s; Url: %s" $time $url
        if {[string is double $time] && ($time < 1)} {
            debug -debug "New url: %s" [set url [get_url $HttpUrl [html unspec $url]]]
            return $url
        }
    }

    return ""
}

#++ thnx to tcllib && wiki.tcl.tk
proc ::gettitle::get_dimensions {data type} {
    debug -debug "trying to get image dimentions; type: %s" $type
    switch -- $type {
        jpg     -
        pjpeg   -
        jpeg {
            proc dimentions {data} {
                set ret [list]

                if {[string range $data 0 2] eq "\xFF\xD8\xFF"} {
                set i 2

                    while {[string index $data $i] eq "\xFF"} {
                        binary scan [string range $data [incr i] $i+2] H2S type len
                        incr i 3
                        # convert to unsigned
                        set len [expr {$len & 0x0000FFFF}]
                        # decrement len to account for marker bytes
                        incr len -2
                        if {[string match {c[0-3]} $type]} {
                            set p $i
                            break
                        }
                        incr i $len
                    }

                    if {[info exists p]} {
                        binary scan [string range $data $p $p+4] cSS precision height width
                        set ret [list $width $height]
                    }
                }

                return $ret
            }
        }
        png {
            proc dimentions {data} {
                set ret [list]
                if {[string range $data 0 7] eq "\x89PNG\r\n\x1a\n"} {
                    set i 0
                    binary scan [string range $data [incr i 8] $i+7] Ia4 len type
                    set r [string range $data [incr i 8] $i+$len]
                    if {$i < [string length $data] && $type eq "IHDR"} {
                        binary scan $r II width height
                        set ret [list $width $height]
                    }
                }
                return $ret
            }
        }
        gif {
            proc dimentions {data} {
                # read GIF signature -- check that this is
                # either GIF87a or GIF89a
                set sig [string range $data 0 5]
                set ret [list]
                if {$sig eq "GIF87a" || $sig eq "GIF89a"} {
                    # read "logical screen size", this is USUALLY the image size too.
                    # interpreting the rest of the GIF specification is left as an exercise
                    binary scan [string range $data 6 7] s wid
                    binary scan [string range $data 8 9] s hgt
                    set ret [list $wid $hgt]
                }
                return $ret
            }
        }
        bmp {
            proc dimentions {data} {
                set ret [list]
                if {[string range $data 0 1] eq "BM"} {
                    binary scan [string range $data 18 21] i width
                    binary scan [string range $data 22 25] i height
                    set ret [list $width $height]
                }

                return $ret
            }
        }
        "svg+xml" {
            proc dimentions {data} {
                set ret [list]
                if {[regexp -- {width="(\d+)(?:\D|\s)} $data - width] \
                        && [regexp -- {height="(\d+)(?:\D|\s)} $data - height]} {
                    set ret [list $width $height]
                }

                return $ret
            }
        }
        default {
            return [list]
        }
    }

    if {[catch {dimentions $data} ret]} {
        debug -err $ret
        set ret [list]
    }

    rename dimentions ""

    return $ret
}
#-- get_dimensions

if 0 {
#++ get_type
proc ::gettitle::get_type {type mtype} {
    switch -exact -- $type {
        "Audio" -
        "Video" -
        "Image" {return [lindex [split $mtype "/"] end]}
        default {return $mtype}
    }

    return 1; # -_-
}
#-- get_type
}

#++ stop_counter
proc ::gettitle::stop_counter {sid} {
    session import

    upvar GTime GTime

    if {[config get showspeed]} {
        set GTime [cformat "main.time" [expr {($EndGet - $StartGet) / 1000}] ms]
    }

    return
}
#-- stop_counter


#++ format_size
proc ::gettitle::format_size {sid} {
    session import

    set size [list]
    lappend size [cformat "size.bytes" $HttpMetaLength B]

    if {[set ksize [expr {$HttpMetaLength / 1024.0}]] >= 1} {
        lappend size [cformat "size.kbytes" [format "%0.1f" $ksize] kB]
    }

    if {[set msize [expr {$HttpMetaLength / 1048576.0}]] >= 1} {
        lappend size [cformat "size.mbytes" [format "%0.2f" $msize] MB]
    }

    unset ksize msize

    return $size
}
#-- format_size

::gettitle::init
