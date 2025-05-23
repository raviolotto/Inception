#!/bin/bash

# Abilita l'uscita immediata in caso di errore
set -e

# Controlla che tutte le variabili d'ambiente necessarie siano definite.
# Queste variabili verranno passate tramite il file .env e docker-compose.
if [ -z "$MYSQL_ROOT_PASSWORD" ] || \
   [ -z "$WORDPRESS_DB_NAME" ] || \
   [ -z "$WORDPRESS_DB_USER" ] || \
   [ -z "$WORDPRESS_DB_PASSWORD" ] || \
   [ -z "$MARIADB_ADMIN_USER" ] || \
   [ -z "$MARIADB_ADMIN_PASSWORD" ]; then
    echo "Errore: Una o più variabili d'ambiente necessarie non sono state impostate."
    echo "Assicurati che MYSQL_ROOT_PASSWORD, WORDPRESS_DB_NAME, WORDPRESS_DB_USER, WORDPRESS_DB_PASSWORD, MARIADB_ADMIN_USER, MARIADB_ADMIN_PASSWORD siano nel tuo .env."
    exit 1
fi

# Percorso della directory dei dati di MariaDB (dove i dati persistono)
MARIADB_DATA_DIR="/var/lib/mysql"

# Controlla se la directory dei dati di MariaDB è già stata inizializzata.
# Questo previene la ri-inizializzazione del database ad ogni riavvio del container,
# dato che i dati sono persistenti tramite un volume.
if [ ! -d "$MARIADB_DATA_DIR/mysql" ]; then
    echo "Inizializzazione della directory dati di MariaDB..."

    # Inizializzare i file di sistema del database.
    # mysqld --initialize crea la directory dei dati e i database di sistema.
    # --datadir punta al volume persistente.
    mysqld --initialize --datadir="$MARIADB_DATA_DIR"

    # Avviare MariaDB in background temporaneamente per eseguire i comandi SQL
    echo "Avvio temporaneo di MariaDB per l'inizializzazione..."
    /usr/sbin/mysqld_safe --datadir="$MARIADB_DATA_DIR" --skip-networking &
    MYSQL_PID=$! # Ottieni il PID del processo in background

    # Attendere che MariaDB sia pronto per accettare connessioni
    echo "In attesa che MariaDB si avvii..."
    until mysqladmin ping -h localhost --silent; do
        echo -n "."
        sleep 1
    done
    echo "MariaDB è attivo!"

    # Eseguire i comandi SQL per configurare il database e gli utenti
    echo "Configurazione del database e creazione degli utenti..."
    mysql -u root <<EOF
        # Impostare la password per l'utente root
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
        FLUSH PRIVILEGES;

        # Creare il database per WordPress se non esiste già
        CREATE DATABASE IF NOT EXISTS \`${WORDPRESS_DB_NAME}\`;

        # Creare l'utente WordPress (l'utente "normale" per l'applicazione)
        CREATE USER IF NOT EXISTS '${WORDPRESS_DB_USER}'@'%' IDENTIFIED BY '${WORDPRESS_DB_PASSWORD}';
        # Grantare tutti i privilegi sul database di WordPress a questo utente
        GRANT ALL PRIVILEGES ON \`${WORDPRESS_DB_NAME}\`.* TO '${WORDPRESS_DB_USER}'@'%';

        FLUSH PRIVILEGES;
EOF

    # Fermare l'istanza temporanea di MariaDB
    echo "Fermando l'istanza temporanea di MariaDB..."
    kill $MYSQL_PID
    wait $MYSQL_PID # Attendere che il processo termini

    echo "Inizializzazione di MariaDB completata."
    # Creare un file flag per indicare che l'inizializzazione è stata eseguita
    # Questo è ridondante con il controllo della directory dati, ma utile per debug.
    # touch /tmp/.db_initialized
else
    echo "MariaDB già inizializzato. Avvio diretto del server."
fi

# Avviare il server MariaDB in foreground come processo principale del container
echo "Avvio di MariaDB in foreground..."
# exec fa sì che mysqld sostituisca lo script shell come PID 1
exec /usr/sbin/mysqld