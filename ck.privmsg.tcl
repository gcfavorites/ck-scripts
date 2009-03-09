encoding system utf-8

::ck::require cmd 0.10

namespace eval ::privmsg {
    variable version 0.1
    variable OriginalAuthor  "adium@RusNet"
    variable author  "kns @ RusNet"

    variable denpr      [list "!" "\$" "%" "&" "." "-" "@" "*" "+" "~" "`" "\?"]
    variable dwords [list \
                        "auth" "addmask" "pass" "ident" \
                        "identauth" "seen" \
                    ]

    namespace import -force ::ck::cmd::*
}


proc ::privmsg::init {  } {

    cmd register privmsg [namespace current]::run \
        -bindpub "privmsg"

    cmd regfilter privmsg [namespace current]::filter -cmd "privmsg" \
        -msg -prio 100

    config register -id "chanout" -type bool -default "0" \
        -desc "Выводить ли сообщения на каналы." -access "n" -folder "privmsg"

    config register -id "ignore" -type str -default "I|-" \
        -desc "Флаг для игнорируемых юзеров." -access "n" -folder "privmsg"

    config register -id "pflag" -type str -default "U" \
        -desc "Флаг для овнеров, которые будут получать сообщение." -access "n" -folder "privmsg"

    msgreg {
        main            &pPrivmsg&n: &K<&r%s&K> &w[&g%s&w] &K:&L:&L:&n %s
    }
}

proc ::privmsg::filter { } {
    variable denpr
    variable dwords

    foreach_ {Text Nick UserHost Handle Channel CmdDCC CmdEvent} { upvar $_ $_ }

    set ign [config get ignore]
    set binds [binds [lindex [split $Text] 0]]
    set Text [string trim [string map [list "\017" "" "\026" ""] [stripcodes bcuarg $Text]]]


    if {($Text ne "") \
            && ![matchattr $Handle n] \
            && ![matchattr $Handle b] \
            && ![llength $binds] \
            && ([string match -nocase {*[a-z]*} $ign] \
                    && ![matchattr $Handle $ign]) \
            && ([lsearch $denpr [string index $Text 0]] == -1) \
            && ([lsearch $dwords [lindex [split $Text] 0]] == -1)} {

        ::ck::cmd::prossed_cmd $CmdEvent $Nick $UserHost $Handle $Channel \
                                    "privmsg $Text" privmsg $CmdDCC FilterMark
    }

    unset ign binds

    return
}


proc ::privmsg::run { sid } {
    session import

    if { $Event eq "CmdPass"  } {
        if {$CmdEventMark eq "FilterMark"} {

            set Text [join [lrange $StdArgs 1 end]]
            set_ ""
            set who ""
            set onick $Nick

            set out [cformat main $Nick $UserHost $Text]

            foreach_ [userlist "n&[config get pflag]"] {
                if {[set who [hand2nick $_]] ne ""} {
                    session set Nick $who
                    reply -noperson $out
                }
            }

            session set Nick $onick

            if {[config get chanout]} {
                session set CmdEvent pub
                reply -noperson -broadcast $out
            }

            unset _ who out onick
        }
    }

    return
}

::privmsg::init