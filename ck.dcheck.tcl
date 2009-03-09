encoding system utf-8
::ck::require cmd
::ck::require http
::ck::require strings

namespace eval ::dcheck {
    variable version 0.1
    variable author "kns@RusNet"

    namespace import -force ::ck::cmd::*
#    namespace import -force ::ck::colors::*
    namespace import -force ::ck::http::http
    namespace import -force ::ck::strings::html

}

proc ::dcheck::init {  } {
    variable enabled_tlds  [etlds]

    cmd register dcheck [namespace current]::run -doc "dcheck" -autousage \
        -bind "dcheck"

    cmd doc "dcheck" {~*!dcheck* [-tlds] [-search] <domain> <зона 1> [зона 2] [зона 3] [зона n]~ - проверка занятости домена.}
    cmd doc "dcheck.tld" {~*!dcheck* -tlds~ - список зон, доступных для проверки.}
    cmd doc "dcheck.search" {~*!dcheck* -search <domain>~ - подбор свободных зон для домена.}

  config register -id "deftlds" -type list \
        -default    [list \
                        "ru" "su" "org" "net" "com" \
                        "info" "biz" "name" "ws" "de" \
                        "net.ru" "org.ru" "pp.ru" "org.ua" "kiev.ua" \
                    ] \
        -desc "Список зон, среди которых будет производиться подбор домена." -access "m" -folder "dcheck"

    msgreg {
        err.http                &BОшибка связи с сайтом&K:&R %s
        tld.list                "&K,&R "
        main.available          &L%s&L: &g%s
        main.error              &L%s&L: &R%s
        main.taken              &L%s&L: &r%s
        available               "&g%s&n"
        tlds                    Зоны, доступные для проверки&K:&R %s&K.&n
        dlist                   " &r:: "
    }
}


proc ::dcheck::run { sid } {
    session import

    if { $Event eq "CmdPass" } {
        variable enabled_tlds

        set Text [lrange $StdArgs 2 end]

        set domain [lindex $StdArgs 1]
        session set searchmode 0

        if {[string first "." $domain] != -1} {
            regexp -- {([^\.]+)\.(.*)} $domain -> domain ->
            lappend Text ${->}
        }

        if {$domain eq "-tlds"} {
            session set CmdReplyParam \
                    [list "-private" "-multi" "-multi-max" "-1" "-return"]
            set txt [cjoin ${enabled_tlds} "tld.list"]
#            debug -info $txt
            reply -return tlds $txt
        } elseif {$domain eq "-search"} {
            set domain [lindex $Text 0]
            set Text [lrange $Text 1 end]

            if {$domain eq ""} {
                replydoc "dcheck.search"
            }

            if {![llength $Text]} {
                set Text [config get "deftlds"]
            }

            session set searchmode 1
        }

        set tlds [list]
        set tlds [lfilter -nocase -keep -- ${enabled_tlds} $Text]

        if {![llength $tlds]} {
            if {$searchmode} {
                replydoc "dcheck.search"
            } else {
                replydoc "dcheck.tld"
            }
        }

        set tlds ".[join $tlds ",."]"
#        debug -info $tlds
         http run "http://input.name/get.php"  \
                -query [list "do" "lookup" "domain" $domain "tlds" $tlds] \
                -mark "Start" \
                -useragent "Opera/9.61 (X11; Linux i686; U; en) Presto/2.1.1" \
                -heads [list "Referer" "http://input.name/"] \
                -cookie [list tlds $tlds checked_tlds $tlds] \
                -return
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

        set HttpData [string stripspace $HttpData]

#        debug -info "regexp"

        set tmp [regexp -all -inline -- \
                    {<DIV CLASS="info_([a-z]+)_head">(\S+)\s*(\S+)</DIV>} \
                $HttpData]

        set_ [list]

        foreach {-> cl dom res} $tmp {
            switch -exact -- $searchmode {
                "1" {if {$cl eq "available"} {lappend_ [cformat available $dom]; continue}}
                default {lappend_ [cformat "main.${cl}" $dom $res]}
            }
        }

#        debug -info "finfo: ${_}"

        session set CmdReplyParam [list "-return"]

        if {[llength $_]} {
            set_ [cjoin $_ dlist]
#            set_ "[string map $::ck::colors::f2m $_]."

            if {[string length $_] > 225} {
                session set CmdReplyParam [list "-return" "-private" "-multi"]
            }
            reply $_
        } else {
            reply -err "Не найдено доступных доменов или ошибка в процессе обработки."
        }

    }
    return
}

proc ::dcheck::etlds {} {
     return                 [list \
                                "ru" "com" "net" "biz" "org" "info" "mobi" "eu" \
                                "name" "in" "ws" "de" "cc" "it" "su" "ua" \
                                "com.ru" "net.ru" "org.ru" "pp.ru" \
                                "msk.ru" "spb.ru" "ru.net" "co.uk" \
                                "com.ua" "net.ua" "org.ua" "kiev.ua" \
                                "ac" "ae" "ag" "al" "at" "au" "as" "be" \
                                "bg" "br" "ca" "cd" "ch" "ck" "cl" "cn" "cx" \
                                "cz" "dk" "ee" "edu" "eg" "es" "fi" "fj" "fo" \
                                "fr" "ge" "gl" "gr" "gs" "gs" "hm" "hk" "hu" \
                                "ie" "int" "is" "il" "jp" "kr" "la" "li" "lk" \
                                "lt" "lu" "lv" "mc" "mil" "mn" "ms" "mx" "nl" \
                                "no" "nz" "pl" "pt" "ro" "se" "sg" "sh" \
                                "si" "sk" "sm" "st" "tc" "th" "to" "tr" \
                                "tv" "tw" "uk" "va" "vg" "ac.cn" "ac.jp" \
                                "ac.uk" "ad.jp" "adm.br" "adv.br" "agr.br" \
                                "ah.cn" "am.br" "arq.br" "art.br" "asn.au" \
                                "ato.br" "bio.br" "bj.cn" "bmd.br" "cim.br" \
                                "cng.br" "cnt.br" "com.au" "com.br" "com.cn" \
                                "com.eg" "com.hk" "com.mx" "com.tw" "conf.au" \
                                "co.jp" "co.uk" "cq.cn" "csiro.au" "ecn.br" \
                                "edu.au" "edu.br" "esp.br" "etc.br" "eti.br" \
                                "eun.eg" "emu.id.au" "eng.br" "far.br" "fj.cn" \
                                "fm.br" "fnd.br" "fot.br" "fst.br" "g12.br" \
                                "gd.cn" "ggf.br" "gr.jp" "gs.cn" "gov.au" \
                                "gov.br" "gov.cn" "gov.hk" "gob.mx" "gz.cn" \
                                "gx.cn" "he.cn" "ha.cn" "hb.cn" "hi.cn" \
                                "hl.cn" "hn.cn" "hk.cn" "id.au" "ind.br" \
                                "imb.br" "inf.br" "info.au" "idv.tw" "jl.cn" \
                                "jor.br" "js.cn" "jx.cn" "lel.br" "ln.cn" \
                                "ltd.uk" "mat.br" "med.br" "mil.br" "ne.jp" \
                                "net.au" "net.br" "net.cn" "net.eg" \
                                "net.hk" "net.lu" "net.mx" "net.uk" \
                                "net.tw" "nm.cn" "mo.cn" "mus.br" "nom.br" \
                                "not.br" "ntr.br" "nx.cn" "plc.uk" "odo.br" \
                                "oop.br" "or.jp" "org.au" "org.br" "org.cn" \
                                "org.hk" "org.lu" "org.tw" "org.uk" "ppg.br" \
                                "pro.br" "psi.br" "psc.br" "qh.cn" "qsl.br" \
                                "rec.br" "sc.cn" "sd.cn" "sh.cn" "slg.br" \
                                "sn.cn" "srv.br" "sx.cn" "tj.cn" "tmp.br" \
                                "trd.br" "tur.br" "tv.br" "tw.cn" "vet.br" \
                                "wattle.id.au" "xj.cn" "xz.cn" \
                                "yn.cn" "zlg.br" "zj.cn" \
                            ]
}

::dcheck::init
