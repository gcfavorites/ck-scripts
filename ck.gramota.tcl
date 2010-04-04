encoding system utf-8
::ck::require cmd
::ck::require http
#::ck::require strings

namespace eval ::gramotaru {
    variable version 0.3
    variable author "kns@RusNet"


    namespace import -force ::ck::cmd::*
    namespace import -force ::ck::http::http
    namespace import -force ::ck::strings::html
}

proc ::gramotaru::init {  } {

    cmd register gramotaru [namespace current]::run -doc "gramotaru" -autousage \
        -bind "gramotaru" -bind "gramota" -bind "dict" -bind "грамота" -bind "словарь"

    cmd doc "gramotaru" {~*!dict* [-число] <слово>~ - поиск значения *слова* на портале gramota.ru}

    msgreg {
        err.http                &BОшибка связи с сайтом&K:&R %s
    }
}


proc ::gramotaru::run { sid } {
    session import

    if { $Event eq "CmdPass" } {

        if {[regexp {^-?(\d+).*} [lindex $StdArgs 1] -> num]} {
            session set num [scan $num %d]
#            debug "num: $num"
            set Text [lindex $StdArgs 2]
            unset ->
        } else {
            set Text [lindex $StdArgs 1]
            session set num 1
        }

        if { [regexp -- {[^А-Яа-яЁё\*\?]} $Text]} {
            reply "можно использовать только буквы русского алфавита и знаки '*','?'."
        } elseif {[string is space $Text]} {
            replydoc gramotaru
        } else {
            http run "http://pda.gramota.ru/" \
                -query [list "action" "dic" "word" $Text] \
                -query-codepage "cp1251" \
                -mark "Start" \
                -useragent "Mozilla/4.0 (compatible; MSIE 4.01; Windows CE; PPC; 240x320)" \
                -heads [list "Referer" "http://pda.gramota.ru/"]
        }

        return
    }

    if { $Mark eq "Start" } {

        if { $HttpStatus < 0 } {
            debug -err "Ошибка запроса '%s'." $HttpError
            reply -err "Ошибка запроса '%s'." $HttpError
            return
        }

#        debug $HttpUrl
#        debug $HttpData

        if {[regexp -- \
                    {<h2>Искомое слово отсутствует</h2>.*<h2>Похожие слова:</h2>\s*(<p style="padding-left:10px">.+?)\s*<div} \
                $HttpData -> data]} {
            regsub -- {<div.*$} $data "" data
            regsub -all -- {<span class="accent">([^<]+)</span>} $data {\&U\1\&U} data

            set w [regexp -all -inline -- {<p style="padding-left:10px">\s*<a[^>]+>\s*<(?:b|STRONG)>\s*([^<]+)</(?:b|STRONG)>} $data]
            set words [list]
            set x 0
            set l [list]
            foreachkv $w {
                incr x
                set v [string trimright $v "\n\t\r 1234567890"]
                if {[lsearch -exact $l $v] == -1} {
                    lappend words "${x}. $v"
                    lappend l $v
                }
                unset k v
            }

            if {[llength $words] > 0} {
                set data "Похожие слова: [join $words {; }]"
            } else {
                set data ""
            }
            unset w words x l
        } elseif {![regsub -- \
                        {.*<h2>Большой толковый словарь</h2>\s*<div style="padding-left:10px">} \
                    $HttpData "" data]} {
# TODO: ускорить получение части. prbl: string first
            set data "Определение в словаре не найдено."
        } else {
            regsub -- {</div>.*$} $data "" data
#            set data [string map [list "<b>" "&L" "</b>" "&L" "<br><li>" "<li>" "<br><br></OL><br>" "\n" "<OL>" "" "\t" " " "<i>" "" "</i>" "" "<br>" ""] $data]
#            set data [string map [list "<b>" "&L" "</b>" "&L" "<br><b>" "\n" "<b><br>" "" "\t" " " "<i>" "" "</i>" "" "<br>" ""] $data]

			set signs [list]
			
			regsub -- {^(.*?)<br><b>\s*1\.</b><br>} $data {\1} data
			regsub -all -- {<br><b>\s*\d+\.</b><br>} $data "\n" data
			set data [string map [list "<b>" "&L" "</b>" "&L" "\t" " " "<i>" "" "</i>" "" "<br>" ""] $data]

#			debug $data

            set signs [split [string trim $data] \n]
            set lsigns [llength $signs]

            if {[incr num -1] >= $lsigns} {set num [expr {$lsigns - 1}]}

            set data [lindex $signs $num]

            regsub -all -- {<span class="accent">([^<]+)</span>} $data {\&U\1\&U} data
            regsub -all -nocase -- {<SUP>[^<]+</SUP>} $data "" data
            regsub -all -- {\(([^\)]+)\)} $data {\&K(\1)\&n} data
	
#			debug [join $signs "\n===\n"]

            set x 0; regsub -- {<li>} $data ": [incr x]. " data
            while {[regsub -- {<li>} $data " [incr x]. " data]} {continue}

            if {$lsigns > 1} {
                set data [format "\[%s/%s\] %s" [incr num] $lsigns $data]
            }

            unset x signs lsigns
        }

        if {$data ne ""} {
            if {[string length $data] > 800} {
                session set CmdEvent msg
                session set CmdReplyParam [list "-multi-max" "4"]
            }
            reply -multi -noperson [html untag [html unspec $data]]
        } else {
            reply -err "Ошибка разбора полученных данных"
        }

        unset data
    }

    return
}

::gramotaru::init
