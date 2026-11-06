//* Просто наброски .service файлу

//[Unit]
//Description=Target Rust Application Service
//After=network.target
//
//[Service]
//Type=simple
//ExecStart=/usr/local/bin/my-service-bin
//Restart=on-failure
//OnFailure=failure-reporter@%n.service
//
//[Install]
//WantedBy=multi-user.target
//






