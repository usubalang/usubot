FROM usuba

RUN sudo apt install -y -qq --no-install-recommends \
                     libgmp-dev pkg-config npm netbase

RUN sudo npm install -g smee-client

RUN git clone https://github.com/usubalang/usubot.git && \
      cd usubot && \
      opam install --deps-only --with-test -y . && \
      opam exec -- dune build

COPY secret/config.toml config.toml
COPY secret/usubot.2022-02-25.private-key.pem usubot.2022-02-25.private-key.pem
COPY service.sh service.sh

CMD ./service.sh
