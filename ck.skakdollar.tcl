encoding system utf-8
::ck::require cmd
::ck::require http
::ck::require strings

namespace eval ::skakdollar {
    variable version 0.1
    variable author "kns@RusNet"


    namespace import -force ::ck::cmd::*
    namespace import -force ::ck::http::http
    namespace import -force ::ck::strings::html

}

proc ::skakdollar::init {  } {

    cmd register skakdollar [namespace current]::run -doc "skakdollar" -autousage \
        -bind "skakdollar" -bind "blond"

    cmd doc "skakdollar" {~*!blond* <word>~ - расшифровка слова для блондинок.}

    msgreg {
        err.http              &BОшибка связи с сайтом&K:&R %s
        join.readas           &n, &p
        join.word             &b.&r
        char                  &P%s&p %s
        main                  &r%s&K:&p %s. Чмоки :-*
    }
}


proc ::skakdollar::run { sid } {
    session import

    if { $Event eq "CmdPass" } {

        set Text [string stripspace [string map [list "\[" "" "\]" "" "\{" "" "\}" ""] [join [lrange $StdArgs 1 end]]]]

		if {$Text eq ""} { replydoc skakdollar }

        http run "http://skakdollar.ru/" \
                -post \
                -query [list "rastalkuy" [string range $Text 0 25] "x" "0" "y" "0"] \
                -mark "Start" \
                -query-codepage cp1251 \
                -useragent "Opera/9.61 (X11; Linux i686; U; en) Presto/2.1.1" \
                -heads [list "Referer" "http://skakdollar.ru/"]
        return
    }

    if { $Mark eq "Start" } {

        if { $HttpStatus < 0 } {
            debug -err "Ошибка запроса '%s'." $HttpError
            reply -err "Ошибка запроса '%s'." $HttpError
            return
        }

        foreach {k v} $HttpMeta {
            debug -debug "k(%s) v(%s)" $k $v
        }

        set HttpData [string map [list "<br>" ""] [string stripspace $HttpData]]

#        debug $HttpData

        if {![regexp -- \
                    {<div id='youaddress'>(.*?)</div>\s*<h2>[^<]+</h2>\s*<div id='readas'>(.*?)</div>} \
                $HttpData -> word readas]} {
            reply -err "Ошибка парсинга"
            return
        }

        set_ [list]
        foreach {-> char} [regexp -all -inline -- {<span>(.*?)</span>} $word] {
            lappend_ [html unspec $char]
        }
        
        set word [cjoin $_ join.word]
        
        set_ [list]
        foreach {-> char} [regexp -all -inline -- {<span>([^<]+)</span>} $readas] {
            set char [split $char]
            lappend_ [string trimright [cformat char [lindex $char 0] [join [lrange $char 1 end]]]]
        }        

        set readas [cjoin $_ join.readas]

        reply -noperson -uniq -multi main $word $readas
    }

    return
}

::skakdollar::init