FROM ubuntu:14.04

ADD http://mirror.racket-lang.org/installers/6.1.1/racket-minimal-6.1.1-x86_64-linux-ubuntu-precise.sh /tmp/install-racket.sh
RUN sh /tmp/install-racket.sh --unix-style --dest /usr && rm /tmp/install-racket.sh
RUN raco pkg install -i --auto -j 4 scribble
RUN raco pkg install -i --auto -j 4 html

RUN apt-get update && apt-get -y install python-pygments
