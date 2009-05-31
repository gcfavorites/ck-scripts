encoding system utf-8
::ck::require cmd
::ck::require http
::ck::require strings

namespace eval ::gramotaru {
    variable version 0.1
    variable author "kns@RusNet"


    namespace import -force ::ck::cmd::*
    namespace import -force ::ck::http::http
    namespace import -force ::ck::strings::html

}

proc ::gramotaru::init {  } {

    cmd register gramotaru [namespace current]::run -doc "gramotaru" -autousage \
        -bind "gramotaru" -bind "dict"

    cmd doc "gramotaru" {~*!dict* <слово>~ - поиск значения *слова* на портале gramota.ru.}

    msgreg {
        err.http                &BОшибка связи с сайтом&K:&R %s
    }
}


proc ::gramotaru::run { sid } {
    session import

    if { $Event eq "CmdPass" } {

        set Text [lindex $StdArgs 1]

        if {[regexp -- {[^А-Яа-яЁё\*\?]} $Text]} {
            reply "можно использовать только буквы русского алфавита и знаки '*','?'."
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
                    {<h2>Искомое слово отсутствует</h2>.*<h2>Похожие слова:</h2>\s*(<p style="padding-left:10px">(.+?))\s*</div>} \
                $HttpData -> data]} {
            regsub -- {</div>.*$} $data "" data
            set data [string map [list "<br>" "" "\n" "" "\r" "" "\t" ""] $data]
            regsub -all -- {</?a[^>]*>} $data "" data

            set w [regexp -all -inline -- {<p style="padding-left:10px">\s*<(?:b|STRONG)>\s*([^<]+)</(?:b|STRONG)>} $data]
            set words [list]
            set x 0
            foreachkv $w {
                incr x
                lappend words "${x}. [string trimright $v]"
                unset k v
            }

            if {[llength $words] > 0} {
                set data "Похожие слова: [join $words {; }]"
            } else {
                set data ""
            }
            unset w words x
        } elseif {![regexp -- \
                    {<h2>Толково-словообразовательный</h2>\s*<div style="padding-left:10px">(.+?)</div>} \
                $HttpData -> data]} {
            set data "Определение в словаре не найдено."
        } else {
            regsub -- {</div>.*$} $data "" data
            set data [string map [list "<B>" "&L" "</B>" "&L" "<br>" "" "\n" "" "\r" "" "\t" ""] $data]
            regsub -all -- {<span class="accent">([^<]+)</span>} $data {\&U\1\&U} data

            if {[regexp -- {^(.*)<OL>(.*?)</OL>.*$} $data - i s]} {
                set s [regexp -all -inline -- {<li>([^<]+)(?:<|>|$)} $s]
                set signs [list]
                set x 0
                foreachkv $s {
                    incr x
                    regsub -all -- {\(([^\)]+)\)} $v {\&K(\1)\&n} v
                    lappend signs "${x}. $v"
                    unset k v
                }

                set data "${i}: [join $signs {; }]"

                unset - i s signs x
            }
        }

        if {$data ne ""} {
#            debug $data
            reply $data
        } else {
            reply -err "Ошибка разбора полученных данных"
        }

        unset data
    }

    return
}

::gramotaru::init
