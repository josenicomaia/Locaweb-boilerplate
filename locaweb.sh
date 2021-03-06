#!/bin/bash

lw_get_script_path() {
    # Pegar o PATH do script (https://stackoverflow.com/a/246128/6465636)
    SOURCE="${BASH_SOURCE[0]}"

    while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
        DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
        SOURCE="$(readlink "$SOURCE")"
        [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    done

    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    echo $DIR
}

LW_DIR=$(lw_get_script_path)

lw_ajuda() {
    echo "Uso: "$(basename $0)" <comando> [pametros...]"
    echo ""
    echo "Comandos:"
    echo "  php <versao=7.1> [env=production|development]:   Faz o ambiente utilizar a versão desejada do PHP."
    echo "    Versoes suportadas:"
    [ -s /usr/bin/php52 ] && echo "     - 5.2"
    [ -s /usr/bin/php53 ] && echo "     - 5.3"
    [ -s /usr/bin/php54 ] && echo "     - 5.4"
    [ -s /usr/bin/php55 ] && echo "     - 5.5"
    [ -s /usr/bin/php56 ] && echo "     - 5.6"
    [ -s /usr/bin/php7 ]  && echo "     - 7.0"
    [ -s /usr/bin/php71 ] && echo "     - 7.1"
    echo "  composer:                                    Instala o composer."
    echo "  ssh:                                         Gera um par de chaves para o SSH utilizando RSA."
    echo "  registrar:                                   Registra o script do LocawebBoilerplate como locaweb."
    echo "  bash:                                        Instala as configurações padroes do bash (baseado no ubuntu)."
    echo "  go:                                          Instala o GO."
}

lw_gerar_chaves_ssh() {
    if [ ! -s $HOME/.ssh/id_rsa ]; then
        echo "Gerando par de chaves do SSH..."
        ssh-keygen -t rsa -f $HOME/.ssh/id_rsa -N ""

        echo ""
        echo "Chave publica:"
        cat $HOME/.ssh/id_rsa.pub
    else
        echo "Já existe um par de chaves gerado."
        echo ""
        echo "Chave publica:"
        cat $HOME/.ssh/id_rsa.pub
    fi
}

lw_instalar_composer() {
    echo "Baixando composer..."
    . php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"

    echo "Instalando composer..."
    . php composer-setup.php

    if [ $? -eq 0 ]; then
        echo "Registrando composer..."
        mv composer.phar $HOME/bin/composer

        echo "Registrado."
    fi

    echo "Apagando instalador..."
    . php -r "unlink('composer-setup.php');"
}

lw_instalar_config_bash() {
    echo "Instalando arquivos de configuracao do Bash..."
    cp $LW_DIR/.bash_logout $HOME/.bash_logout
    cp $LW_DIR/.bash_profile $HOME/.bash_profile
    cp $LW_DIR/.bashrc $HOME/.bashrc
    cp $LW_DIR/.bash_aliases $HOME/.bash_aliases

    echo "Carregando configuracoes..."
    source $HOME/.bash_profile

    echo "Carregado."
}

lw_instalar_config_php() {
    PHP_VERSION=${1-"7.1"}
    PHP_ENV=${2-"production"}

    if [ ! -d $HOME/php/$PHP_VERSION ]; then
        echo "Instalando arquivos de configuracao do PHP..."

        if [ ! -d $HOME/tmp ]; then
            mkdir -p $HOME/tmp
            chmod 777 $HOME/tmp
        fi

        echo "Copiando configurações do CGI..."
        mkdir -p $HOME/php/$PHP_VERSION/cgi
        sed "s/LOCAWEB_USER/$USER/g" $LW_DIR/php/$PHP_VERSION/cgi/php.ini-$PHP_ENV > $HOME/php/$PHP_VERSION/cgi/php.ini

        echo "Copiando configurações do CLI..."
        mkdir -p $HOME/php/$PHP_VERSION/cli
        sed "s/LOCAWEB_USER/$USER/g" $LW_DIR/php/$PHP_VERSION/cli/php.ini-$PHP_ENV > $HOME/php/$PHP_VERSION/cli/php.ini
    fi
}

lw_instalar_go() {
    echo "Baixando GO..."
    curl -o go1.10.3.linux-amd64.tar.gz "https://dl.google.com/go/go1.10.3.linux-amd64.tar.gz"
    echo "Instalando GO..."
    tar -xzf go1.10.3.linux-amd64.tar.gz
    echo "Apagando instalador..."
    rm go1.10.3.linux-amd64.tar.gz
}

lw_php() {
    PHP_VERSION=${1-"7.1"}
    PHP_ENV=${2-"production"}

    echo "Versão selecionada do PHP: $PHP_VERSION"
    lw_instalar_config_php $PHP_VERSION $PHP_ENV

    if [ -d $LW_DIR/php/$PHP_VERSION ]; then
        if [ -f $HOME/bin/php ]; then
            rm $HOME/bin/php
        fi

        echo "Registrando versao do PHP para linha de comando (CLI)..."
        cp $LW_DIR/php/$PHP_VERSION/cli/php$PHP_VERSION.sh $HOME/bin/php
        chmod +x $HOME/bin/php
        cp $LW_DIR/php/$PHP_VERSION/cli/phpize$PHP_VERSION.sh $HOME/bin/phpize
        chmod +x $HOME/bin/phpize
        cp $LW_DIR/php/$PHP_VERSION/cli/php$PHP_VERSION-config.sh $HOME/bin/php-config
        chmod +x $HOME/bin/php-config

        echo "Fazendo backup do .htaccess em /home/$USER/htacess.bkp..."
        cp $HOME/public_html/.htaccess $HOME/htaccess.bkp
        echo "Registrando versao do PHP para WEB (CGI)..."
        awk '!/AddHandler php[0-9]*-script/' $HOME/public_html/.htaccess | awk '!/suPHP_ConfigPath/' | sed '1{/^[[:space:]]*$/d}' > /tmp/htaccess_corpo
        sed "s/LOCAWEB_USER/$USER/g" $LW_DIR/php/$PHP_VERSION/.htaccess > /tmp/htaccess
        echo "" >> /tmp/htaccess
        echo "" >> /tmp/htaccess
        cat /tmp/htaccess_corpo >> /tmp/htaccess
        rm /tmp/htaccess_corpo
        mv /tmp/htaccess $HOME/public_html/.htaccess
        cp $LW_DIR/php/$PHP_VERSION/cgi/php$PHP_VERSION-cgi.sh $HOME/bin/php-cgi
        chmod +x $HOME/bin/php-cgi

        echo ""
        command php -v
    else
        echo "Configurações não encontradas!"
    fi
}

lw_registrar() {
    if [ ! -d $HOME/bin ]; then
        mkdir -p $HOME/bin
    fi

    echo "Registrando LocawebBoilerplate..."
    ln -s $LW_DIR/locaweb.sh /home/$USER/bin/lw

    echo "Registrado."
}

case "$1" in
    php)
        lw_php $2 $3
    ;;

    composer)
        lw_instalar_composer
    ;;

    ssh)
        lw_gerar_chaves_ssh
    ;;

    registrar)
        lw_registrar
    ;;

    bash)
        lw_instalar_config_bash
    ;;

    go)
        lw_instalar_go
    ;;

    *)
        lw_ajuda
    ;;
esac

# Limpando as variáveis e funções do SCRIPT
unset LW_DIR
unset lw_ajuda
unset lw_instalar_composer
unset lw_instalar_config_bash
unset lw_instalar_config_php
unset lw_instalar_go
unset lw_gerar_chaves_ssh
unset lw_php
unset lw_registrar
unset lw_get_script_path
