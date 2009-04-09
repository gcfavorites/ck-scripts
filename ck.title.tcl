encoding system utf-8

::ck::require cmd 0.10
::ck::require http 0.5
::ck::require strings

namespace eval ::gettitle {
    variable version 0.4
    variable author  "kns @ RusNet"


# префиксы команд, сообщения с ними орабатываться не будут
    variable denpr      [list "!" "\$" "%" "&" "." "-" "@" "*" "+" "~" "`" "\?"]


# разрешенные Content-Type. маски не поддерживаются (а, может быть, поддерживаются :)))
    variable alltypes   [list "text/html" "text/wml" "text/vnd.wap.wml" \
                          "text/xml" "application/xml" "application/rss+xml" \
                        ]


# переменная, в которой будут храниться игноры
    variable tignores [list]

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
        -desc "Автоматически выхватывать ссылки из сообщений на каналах" -access "n" -folder "gettitle"

    config register -id "forceonchans" -type list -default [list] \
        -desc "Форсировать автоматическую обработку сообщений в канале." -access "n" -folder "gettitle" \
        -disableon [list "auto" 1]

    config register -id "ignore" -type str -default "I|-" \
        -desc "Флаг для игнорируемых юзеров." -access "n" -folder "gettitle"

    config register -id "maxlen" -type int -default 200 \
        -desc "Максимальная длина выводимого заголовка" -access "n" -folder "gettitle"

    config register -id "readlimit" -type int -default 11264 \
        -desc "Максимальное число загружаемых байтов" -access "n" -folder "gettitle"

    config register -id "showsize" -type bool -default 0 \
        -desc "Показывать размер файла (пока сделано только для изображений)" -access "n" -folder "gettitle"

    config register -id "showspeed" -type bool -default 0 \
        -desc "Показывать скорость получения ссылки" -access "n" -folder "gettitle"
#-- configs


    set tignores [datafile getlist tignores]

    msgreg {
        err.badurl      эта строка не похожа на ссылку

        main.inf        &L&pURL title&L%s&n: %s
        main.time       " &K(&g%s %s&K)"
        main.url        &K<&B%s&K>&n
        main.size       &L&p%s&L%s&n. Size: %s.

        size.bytes      &g%s&n %s
        size.kbytes     &r%s&n %s
        size.mbytes     &R%s&n %s

        exists          &K<&R%s&K>&n уже в списке игнорирования &K(&g%s&K)&n
        notexists       &K<&R%s&K>&n не найден в списке игнорирования

        add             &K<&R%s&K>&n добавлен в список игнорирования
        del             &K<&R%s&K>&n удален из списка игнорирования

        found           &K<&R%s&K>&n найден в списке игнорирования &K(&g%s&K)&n
        notfound        &K<&R%s&K>&n не найден в списке игнорирования

        ignores         список игнорования: &R%s&n.
        join.ignores    "&K,&R "
        join.size       " &K::&R "
    }
}

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


proc ::gettitle::filter { } {
    foreach_ {Text Nick UserHost Handle Channel CmdDCC CmdEvent} { upvar $_ $_ }

    if {![config get auto] \
            && ![llength [lfilter -keep -nocase -- [config get forceonchans] $Channel]]} {
#        debug -debug "automode disabled"
        return
    }

    variable denpr

    set url ""
    set ign [config get ignore]
    set binds [binds [lindex [split $Text] 0]]

    if {([lsearch $denpr [string index $Text 0]] == -1) \
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
            return
        }

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

        http run $url \
            -mark "Get" \
            -norecode \
            -readlimit [config get readlimit] \
            -redirects 5 \
            -useragent "Opera/9.62 (X11; Linux i686; U; en) Presto/2.1.1"

        unset url
        return
    }

    if { $Mark eq "Get" } {
        set GetTime [clock clicks]; # замеряем время получения
        session import StartGet

        if { $HttpStatus < 0 } {
            debug -err "Ошибка запроса '%s'." $HttpError
            if {$CmdEventMark eq ""} { reply -err "Ошибка запроса: '%s'." $HttpError }
            return
        }

#        debug -debug "GetTime: %0.3f ms" [expr {($GetTime - $StartGet) / 1000.0}]

#        debug $HttpUrl

        variable alltypes

        if {([lsearch $alltypes $HttpMetaType] != -1)} {

            set title [get_title $HttpData $HttpMetaCharset]

            set title [string stripspace [html unspec [html untag $title]]]

            set maxlen [config get maxlen]

            if {$title ne ""} {
                debug -debug- "title: $title"

                if {[string length $title] > ${maxlen}} {
                    set title [string trimright [string range $title 0 [expr ${maxlen}-3]] [list "." " " "," ":" ";" "¤" "-"]]
                    append title "..."
                }

                set EndGet [clock clicks]; # останавливаем счетчик
                if {[config get showspeed]} {
                    set GTime [cformat "main.time" [expr {($EndGet - $StartGet) / 1000}] ms]
                } else {
                    set GTime ""
                }

                reply -noperson -uniq "main.inf" $GTime [cformat "main.url" $title]
            } else {
                debug -debug "Title is empty"
                if {$CmdEventMark eq ""} { reply -err "ошибка: пустой заголовок"}
            }

            unset maxlen title

        } elseif {[config get showsize]} {
            debug -debug "Trying to get file size"

            switch -glob -- [string tolower $HttpMetaType] {
                "image/*" {set type "Image"}
                "audio/*" {set type "Audio"}
                "video/*" {set type "Video"}
                "application/*zip*"         -
                "application/*compress*"    -
                "application/*tar*"         -
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

                set_ [list]

                lappend_ [cformat "size.bytes" $HttpMetaLength B]

                if {[set ksize [expr {$HttpMetaLength / 1024.0}]] >= 1} {
                    lappend_ [cformat "size.kbytes" [format "%0.1f" $ksize] kB]
                }

                if {[set msize [expr {$HttpMetaLength / 1048576.0}]] >= 1} {
                    lappend_ [cformat "size.mbytes" [format "%0.2f" $msize] MB]
                }

                set EndGet [clock clicks]
                if {[config get showspeed]} {
                    set GTime [cformat "main.time" [expr {($EndGet - $StartGet) / 1000}] ms]
                } else {
                    set GTime ""
                }

                reply -noperson -uniq "main.size" $type $GTime [cjoin $_ "join.size"]

                unset ksize msize GTime _
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

    	# юзаем foreach для совместимости
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

proc ::gettitle::get_cp {data metacp} {
    if {![regexp -nocase -- {<meta[^>]+charset\s*=\s*([^\s\"\'>]+).*?>} $data -> cp] \
            && ![regexp -nocase -- {<?xml\s+version[^>]+encoding="([^\s\'\/\>]+)"} $data -> cp]} {

        set cp $metacp
        debug -debug- "set cp \$metacp"
    } else {unset ->}

    debug -debug- "MetaCp: $metacp"
    debug -debug- "rawcp: $cp"

    set ret [::ck::http::charset2encoding $cp]

    if {$ret eq "binary"} {
        set ret "cp1251"
#        set ret $::ck::ircencoding
    }

    debug -debug- "ret: $ret"

    unset data metacp cp

    return $ret
}

proc ::gettitle::get_title {data metacp} {

    set ret ""

    if {![regexp -nocase -- {<title>(.*?)</title>} $data -> title] \
            && ![regexp -nocase -- {<meta[^>]+name="title"[^>]+content="([^\"]+)"} $data -> title] \
            && ![regexp -nocase -- {<card[^>]+title="([^\"]+)"} $data -> title]} {
        debug -err "Title not found"
    } else {
        debug -debug "rawtitle: \"$title\""

        set cp [get_cp $data $metacp]

#++ Попытка выправить кодировку
        debug -debug "String in the detected cp: '%s'" [encoding convertfrom $cp $title]
        debug -debug- "Trying to verify the codepage"
        regsub -all -- {[^а-яА-ЯёЁ]} [encoding convertfrom $cp $title] "" cyrtitle
        debug -debug- "Cyrillic part of the line: %s" $cyrtitle

        if {($cp eq "cp1251") && ([string length [set cyrtitle [string range $cyrtitle 0 4]]] > 4) \
                && ($cyrtitle eq "[string tolower [string index $cyrtitle 0]][string toupper [string range $cyrtitle 1 end]]")} {
            debug -debug "Возможно неправильное определение кодировки (%s), пробуем %s" $cp "koi8-r"
            set cp "koi8-r"
        }
#--

        set ret [encoding convertfrom $cp $title]

        unset -> title
    }

    unset data

    return $ret
}

::gettitle::init
