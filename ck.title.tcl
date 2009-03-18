encoding system utf-8

::ck::require cmd 0.10
::ck::require http 0.5
::ck::require strings

namespace eval ::gettitle {
    variable version 0.3
    variable author  "kns @ RusNet"


# префиксы команд, сообщения с ними орабатываться не будут
    variable denpr      [list "!" "\$" "%" "&" "." "-" "@" "*" "+" "~" "`" "\?"]


# разрешенные Content-Type. маски не поддерживаются
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



    config register -id "auto" -type int -default 1 \
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



    set tignores [datafile getlist tignores]

    msgreg {
        err.badurl      эта строка не похожа на ссылку

        main            &L&ptitle&L&n: &K<&B%s&K>&n

        exists          домен или шаблон &K<&R%s&K>&n уже в списке игнорирования &K(&g%s&K)&n
        notexists       домен или шаблон &K<&R%s&K>&n не найден в списке игнорирования

        add             домен или шаблон &K<&R%s&K>&n добавлен в список игнорирования
        del             домен или шаблон &K<&R%s&K>&n удален из списка игнорирования

        found           домен или шаблон &K<&R%s&K>&n найден списке игнорирования &K(&g%s&K)&n
        notfound        домен или шаблон &K<&R%s&K>&n не найден списке игнорирования

        join.ignores    "&K,&R "
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
            && ([string match -nocase {*[a-z]*} $ign] \
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
        set url [lindex [split [lindex $StdArgs 1] "#"] 0]

        if {[string first "." $url] < 1 || [string length $url] < 4} {
            reply -err badurl
            return
        }

        if {$CmdEventMark eq "FilterMark"} {
            variable tignores

            regexp -- {^(?:https?://)?(?:www\.)?([^/\?]+)} $url -> dom
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
        if { $HttpStatus < 0 } {
            debug -err "Ошибка запроса '%s'." $HttpError
            if {$CmdEventMark eq ""} { reply -err "Ошибка запроса: '%s'." $HttpError }
            return
        }

#		debug $HttpUrl

        variable alltypes

#        if {[info exists HttpMetaType]} {
#            set ContentType [string trim [string tolower HttpMetaType]]
#        } else {
#            set ContentType ""
#        }

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

                reply -noperson -uniq main $title
            } else {
                debug -debug "\$title is empty"
                if {$CmdEventMark eq ""} { reply -err "ошибка: пустой заголовок"}
            }

            unset maxlen title

        } else {
            debug -debug "Unknown 'Content-Type': '%s'" $HttpMetaType
            if {$CmdEventMark eq ""} { reply -err "ошибка: неизвестный \"Content-Type\""}
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
                    reply found $Text $i
    		} else {
                    reply notfound $Text
    		}
            }

            "gettitlelist" {
                set_ [cjoin $tignores "join.ignores"]

                if {[string length $_] > 225} {
                    session set CmdReplyParam [list "-private" "-multi" "-multi-max" "-1" "-return"]
                }
                reply $_
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
#        set ret "cp1251"
        set ret $::ck::ircencoding
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

    if {($cp eq "cp1251") && ([set cyrtitle [string range $cyrtitle 0 4]] ne "") \
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