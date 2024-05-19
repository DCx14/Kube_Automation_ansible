# Déploiement d'un cluster kubernetes

## Attention a ne pas déployer pour de la production.

## prérequis:

- Rocky 8.9
- ansible


## Mise en place.

```shell
hostnamectl set-hostname Master #changeme
hostnamectl set-hostname Node1  #changeme
hostnamectl set-hostname Node2  #changeme
```

Modifier le fichier main.yml:

    - hosts: servers
      vars:
        master: 10.10.100.100 #changeme
        node1: 10.10.100.101 #changeme
        node2: 10.10.100.102 #changeme
        rangeMetallb: 10.10.100.180-10.10.100.230  #changeme


Et lancer l'installation
  
```shell
ansible-playbook -i hosts main.yml
```
