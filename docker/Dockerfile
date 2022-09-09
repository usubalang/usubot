FROM usuba

RUN sudo npm install -g smee-client

RUN sudo apt install -y -qq --no-install-recommends \
                     libgmp-dev pkg-config npm

RUN git clone https://github.com/usubalang/usubot.git && \
      cd usubot && \
      opam install --deps-only --with-test -y . && \
      opam exec -- dune build

COPY secret/config.toml config.toml
COPY secret/usubot.2022-02-25.private-key.pem usubot.2022-02-25.private-key.pem
COPY secret/smee_endpoint.txt smee_endpoint.txt
COPY service.sh service.sh

CMD ./service.sh