# Stack Mapping

Plataforma de inventário integrado com automatização de infraestrutura e serviços.

## Objetivo
Coletar informações e configurações dos serviços IIS, Apache, Nginx, MySQL, PostreSQL entre outros e fazer o armazenamento das configurações com quatro propósitos:

1. Inventário detalhado incluindo as configurações dos serviços e servidores.
2. Backup centralizado das configuração dos serviços no Consul.
3. Provisionamento automático e padronizado de novos servidores e serviços utilizando Ansible e parâmetros armazenados no Consul.
4. Organizar nomeclatura de nome (DNS) dos servidores do invetário.

## Coleta das informações e configurações

O processo de coleta das informações é feito através do Ansible e armazenada através de uma API no Consul:

1. O Ansible ou o AWX utilizando playbooks e inventorys se conecta em servidores Linux ou Windows e através de comandos internos ou funções do própio Ansible coleta as informações de hardware e serviços.
1.1. Os serviços da AWS são coletados através de uma execução local do Ansible utilizando aws-cli.

Um bloco de exemplo da playbook:

```
- name: ADD HOSTNAME VALUE ON CONSUL
  consul_kv:
    host: consul.domain.net
    port: 8500
    key: {{ ansible_hostgroup }}/hosts/{{ ansible_hostname }}/hardware/net/{{ ansible_hostname }}
    value: "{{ ansible_hostname }}"

```

2. As configurações e informações são tratadas através das funções do Ansible e enviadas para o Consul via HTTP e respeitando a estrutura de um modelo de armazenamento
2.2 O servidor também é ingressado no servidor de DNS do Consul com o propósito de mapeamento

3. As informações e configurações dos serviços ficam armazenadas no Consul e disponiveis para consulta através da interface do Consul ou API

![consul-key](https://user-images.githubusercontent.com/4332906/59002277-3e5dae00-87e8-11e9-86ec-4350edcf6f54.png)

Acessando as chanves através do CURL:
```
curl http://127.0.0.1:8500/v1/kv/localhost/hosts/linux/nbvagnerd/net/hostname?raw=true
```

_Estrutura da coleta de informações_
<p align="center">
<img src="https://user-images.githubusercontent.com/4332906/58753156-b26b1f80-8491-11e9-8956-91ab6084554f.png">
</p>

## Extração dos dados da API para CSV
O processo de extração dos dados pode ser feito de diversas maneiras os dados armanzenados no KV do Consul pode ser extraido através de sua [API](https://www.consul.io/api/kv.html) desta forma somente sendo necessário fazer a combinação ideal com algum script Python ou até mesmo Shell Script para coletar todos os dados e exportar para CSV por exemplo.

Com a flexibilidade da API os dados podem ser consumidos por outras ferramentas de relatórios desta forma não limitando a saída dos dados somente para planilhas.

_Estrutura da extração dos dados_
![Extracao_de_Dados](https://user-images.githubusercontent.com/4332906/59004232-54bb3800-87ef-11e9-95d6-6d6ede75f68c.png)

### Exemplo de extração através de shell script (extract.sh):
```
extract.sh vms_locais ~/Desktop/vms_locais.csv
```
<p align="center">
<img src="https://user-images.githubusercontent.com/4332906/59266637-7a48a700-8c1e-11e9-80a0-167acd439a67.png">
</p>

### Exemplo de extração através do PHP consumindo a API:
```php
function GET_HOSTS($CONSUL_URL, $HOST_GROUP, $OS, $HOSTS) {
  $INFOS = array("net/hostname", "generic/os", "hardware/cpu", "hardware/cpu_model", "hardware/memory", "hardware/disk");

  foreach($HOSTS as $KV_HOST) {
    echo "\t<tr>\n";
    echo "\t\t<td>$KV_HOST</td>\n";

    foreach($INFOS as $KV_INFO) {
      echo "\t\t<td>".file_get_contents("$CONSUL_URL/$HOST_GROUP/hosts/$OS/$KV_HOST/$KV_INFO?raw")."</td>\n";
    }
    
    echo "\t</tr>\n";

  }
}
```
<p align="center">
<img src="https://user-images.githubusercontent.com/4332906/60745766-0f0aa000-9f52-11e9-964c-2291ed9458a5.png">
</p>

## Provisionamento automático de infraestrutura
O provisionamento automático ou a cereja do bolo é o propósito mais interessante do stack mapping, ele tem como objetivo a base das configurações armazenadas no Consul como parâmetro para o provisionamento de novos servidores e serviços ou seja as mesmas informações coletadas para o inventário podem ser utilizadas para provisionar um novo servidor ou serviço de forma automática e padronizada com o Terraform e Ansible, abaixo um descritivo das possibilidades com as duas ferramentas:

* Terraform: Com as informações de Hardware coletadas para o inventário é possivel disparar novos servidores com as mesmas configurações e de forma automática.
* Ansible: Com as informações dos serviços coletados para o invetário é possivel provisionar e configurar novos serviços de forma padronizada, automatizada e de forma segregada sendo possível distribuir os serviços.

_A cereja do bolo_

Considerando que através do inventário o cliente identificou altos custos em seu provedor de cloud atual e deseja migrar seus servidores e serviços para uma nova provedora de cloud com custos mais baixos, com o stack mapping isso é possível ser feito de forma rápida, padronizada e totalmente automatizada. Não necessariamente o ambiente produtivo mas os ambientes de testes por exemplo podem ser migrados para avaliar o desempenho na nova provedora de cloud.

Esta função também permite por exemplo reorganizar,padronizar e automatizar a infraestrutura do cliente internamente, até mesmo em casos de atualizações de parques e de alterações de arquitetura.

__A infraestrutura fica totalmente modelável, padronizada e automatizada com base no inventário do cenário atual.__

Abaixo um bloco de uma playbook exemplificando o uso de uma configuração armzenada no Consul e o provisionamento do hostname de um servidor:

```
- name: REGISTER HOSTNAME ENV FROM CONSUL KV
  uri:
    url: "http://consul.domain.net:8500/v1/kv/{{ inventory_hostname }}/hosts/linux/{{ ansible_hostname }}/net/hostname?raw=true"
    return_content: yes
  register: consul_kv_hostname

- name: SET HOSTNAME
- hostname:
    name: "{{ consul_kv_hostname.content }}"

 ```

_Estrutura do provisionamento automático_
<p align="center">
<img src="https://user-images.githubusercontent.com/4332906/59004716-06a73400-87f1-11e9-8097-b2c1e95a2f6a.png">
</p>

## Mapeamento DNS
O Consul também tem suporte a DNS, ou seja durante o levantamento do invetário também é possível organizar ou mapear todos os servidores em um contexto DNS que dentro das boas práticas é considerado um ato importante para a organização da infraestrutura. 

## Integração com monitoramento
Com este modelo de automação de infraestrutura com Ansible é possivel que a nova infraestrutura do cliente esteja totalmente integrada e padronizada com diversas ferramentas e formas de monitoramento, também podemos considerar este modelo para rotinas de backup.

## Modelo para armazenamento no KV Consul
```
<HostGroup Name>/hosts.index
<HostGroup Name>/hosts/<Hostname>/generic/os
<HostGroup Name>/hosts/<Hostname>/hardware/cpu
<HostGroup Name>/hosts/<Hostname>/hardware/cpu_model
<HostGroup Name>/hosts/<Hostname>/hardware/disk
<HostGroup Name>/hosts/<Hostname>/hardware/memory
<HostGroup Name>/hosts/<Hostname>/net/dns
<HostGroup Name>/hosts/<Hostname>/net/gateway
<HostGroup Name>/hosts/<Hostname>/net/hostname
```
```
<HostGroup Name>/hosts/<Hostname>/iis/generalconfig
<HostGroup Name>/hosts/<Hostname>/iis/pools/pool1
<HostGroup Name>/hosts/<Hostname>/iis/pools/pool1/app1
<HostGroup Name>/hosts/<Hostname>/iis/pools/pool1/app2
```
```
<HostGroup Name>/hosts/<Hostname>/nginx/vhosts.index
<HostGroup Name>/hosts/<Hostname>/nginx/vhosts/vhost1/listen
<HostGroup Name>/hosts/<Hostname>/nginx/vhosts/vhost1/location
<HostGroup Name>/hosts/<Hostname>/nginx/vhosts/vhost1/proxy
<HostGroup Name>/hosts/<Hostname>/nginx/vhosts/vhost1/root_dir
<HostGroup Name>/hosts/<Hostname>/nginx/vhosts/vhost1/server_name
```

## Softwares utilizados
* [AWX](https://github.com/ansible/awx) - Interface WEB de gerenciamento do Ansible
* [Ansible](https://www.ansible.com/) - Ferramenta de automatização multiplataforma
* [Consul](https://www.consul.io/) - Ferramenta para descoberta, monitoramento e configuração de serviço
* [Terraform](https://www.terraform.io/) - Ferramenta para construir e alterar infra-estrutura

## To Do
- [x] Instalação e configuração de servidor AWX
- [ ] Desenvolvimento de playbook para instalação e configuração do Consul
- [ ] Provisionamento automático do Consul através do Ansible
- [x] Criação do modelo de estrutura para armazenamento dos dados no KV do Consul
- [ ] Cadastramento dos servidores, credenciais e enviroments no AWX
- [x] Estudo/POC de script Python, Shell Script e Power Shell para coleta das informações com OUTPUT para o Consul 
- [ ] Desenvolvimento dos playbooks para invetário da plataforma Windows (IIS/SQL Server...)
- [ ] Desenvolvimento dos playbooks para invetário da plaforma Linux (Apache/Nginx/MySQL...)
- [ ] Desenvolvimento dos playbooks para invetário da plaforma AWS (RDS,EC2...)
- [x] Refinamento das playbooks para OUTPUT dos dados para o Consul
- [ ] Desenvolvimento de script Python, Shell Script ou WI para exportar dados JSON > CSV
- [ ] Desenvolvimento de playbooks para provisionamento de novos serviços Windows com INPUT das configurações (KV) do Consul
- [ ] Desenvolvimento de playbooks para provisionamento de novos serviços Linux com INPUT das configurações (KV) do Consul
- [ ] Desenvolvimento de playbooks para provisionamento de novos serviços AWS com INPUT das configurações (KV) do Consul

## Links de referência
* [Consul](https://www.youtube.com/watch?v=0erwMnIG0tc) - Video sobre o consul
* [KV Module](https://docs.ansible.com/ansible/2.4/consul_kv_module.html) - Módulo do Key Value para Ansible

## DESC
Este documento tem como objetivo principal oferecer a proposta da ideia como produto, e questionar o paradigma "Mas isso já foi automatizado?".

Autor: _Vagner Rodrigues Fernandes <vagner.rodrigues@gmail.com>_

Versão: 1.1.1
