#!/bin/bash

# Abilita l'uscita immediata in caso di errore
set -e

# Controlla che tutte le variabili d'ambiente necessarie siano definite
if [ -z "$MYSQL_ROOT_PASSWORD" ] || \
   [ -z "$WORDPRESS_DB_NAME" ] || \
   [ -z "$WORDPRESS_DB_USER" ] || \
   [ -z "$WORDPRESS_DB_PASSWORD" ]; then
    echo "Errore: Una o più variabili d'ambiente necessarie non sono state impostate."
    echo "Assicurati che MYSQL_ROOT_PASSWORD, WORDPRESS_DB_NAME, WORDPRESS_DB_USER, WORDPRESS_DB_PASSWORD siano nel tuo .env."
    exit 1
fi

# Percorso della directory dei dati di MariaDB
MARIADB_DATA_DIR="/var/lib/mysql"

# Controlla se MariaDB è già stata inizializzata
if [ ! -d "$MARIADB_DATA_DIR/mysql" ]; then
    echo "Inizializzazione della directory dati di MariaDB..."

    # Inizializzare MariaDB con mysql_install_db (più appropriato per MariaDB)
    mysql_install_db --user=mysql --datadir="$MARIADB_DATA_DIR"

    # Avviare MariaDB in modalità sicura temporaneamente
    echo "Avvio temporaneo di MariaDB per l'inizializzazione..."
    mysqld_safe --datadir="$MARIADB_DATA_DIR" --skip-networking --skip-grant-tables &
    MYSQL_PID=$!

    # Attendere che MariaDB sia pronto
    echo "In attesa che MariaDB si avvii..."
    sleep 5
    
    # Tentativo più robusto di attendere MariaDB
    for i in {1..30}; do
        if mysqladmin ping -h localhost --silent 2>/dev/null; then
            break
        fi
        echo -n "."
        sleep 1
    done
    echo "MariaDB è attivo!"

    # Configurazione iniziale con skip-grant-tables attivo
    echo "Configurazione iniziale del database..."
    mysql -u root <<EOF
        -- Flush privileges per abilitare la gestione degli utenti
        FLUSH PRIVILEGES;
        
        -- Impostare la password per root
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
        
        -- Creare utente root che può connettersi da qualsiasi host (per Docker)
        CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
        GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
        
        -- Creare il database per WordPress
        CREATE DATABASE IF NOT EXISTS \`${WORDPRESS_DB_NAME}\` 
        CHARACTER SET utf8mb4 
        COLLATE utf8mb4_unicode_ci;
        
        -- Creare l'utente WordPress
        CREATE USER IF NOT EXISTS '${WORDPRESS_DB_USER}'@'%' 
        IDENTIFIED BY '${WORDPRESS_DB_PASSWORD}';
        
        -- Grantare privilegi all'utente WordPress
        GRANT ALL PRIVILEGES ON \`${WORDPRESS_DB_NAME}\`.* 
        TO '${WORDPRESS_DB_USER}'@'%';
        
        -- Rimuovere utenti anonimi e database di test per sicurezza
        DROP USER IF EXISTS ''@'localhost';
        DROP USER IF EXISTS ''@'%';
        DROP DATABASE IF EXISTS test;
        
        FLUSH PRIVILEGES;
EOF

    # Verificare che il database sia stato creato
    echo "Verifica della creazione del database..."
    if mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "USE \`${WORDPRESS_DB_NAME}\`; SHOW TABLES;" 2>/dev/null; then
        echo "Database ${WORDPRESS_DB_NAME} creato correttamente!"
    else
        echo "ATTENZIONE: Possibili problemi nella creazione del database"
    fi

    # Fermare l'istanza temporanea
    echo "Fermando l'istanza temporanea di MariaDB..."
    kill $MYSQL_PID 2>/dev/null || true
    wait $MYSQL_PID 2>/dev/null || true
    
    # Attendere che il processo termini completamente
    sleep 2

    echo "Inizializzazione di MariaDB completata."
else
    echo "MariaDB già inizializzato. Avvio diretto del server."
fi

# Avviare MariaDB in foreground
echo "Avvio di MariaDB in modalità normale..."
exec mysqld --user=mysql --datadir="$MARIADB_DATA_DIR" --bind-address=0.0.0.0