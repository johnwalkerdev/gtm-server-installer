# GTM Server-Side Installer

Instalador automático para Google Tag Manager Server-Side Container com suporte a múltiplos projetos.

## ⚡ Instalação Rápida

Execute este comando para instalar diretamente do seu GitHub:
```bash
curl -s https://raw.githubusercontent.com/johnwalkerdev/gtm-server-installer/main/install.sh | sudo bash
```

## 🔧 O que você precisa ter:

1. Um servidor Ubuntu/Debian
2. Docker e Docker Compose instalados
3. Caddy instalado
4. Um domínio base apontando para o servidor

## 🚀 O que o instalador faz:

1. Cria estrutura para seu projeto GTM
2. Configura container principal e preview
3. Configura SSL automático
4. Gera URLs amigáveis para seu projeto

## 📝 Durante a instalação você irá informar:

1. Nome do projeto (ex: contaideal)
2. Domínio base (ex: huskycontent.com)
3. Container Configuration do GTM

## 🌐 O instalador vai criar:

- URL Principal: `https://gtm-[projeto].[seu-dominio]`
- URL Preview: `https://preview-gtm-[projeto].[seu-dominio]`

## 📦 Instalação Manual

Se preferir instalar manualmente:

1. Clone o repositório:
```bash
git clone https://github.com/johnwalkerdev/gtm-server-installer.git
cd gtm-server-installer
```

2. Execute o instalador:
```bash
sudo ./install.sh
```

## 🛠️ Comandos Úteis

### Ver status dos containers
```bash
docker ps | grep [nome-do-projeto]
```

### Reiniciar containers
```bash
cd /opt/[projeto]_gtm/gtm-[projeto] && docker-compose restart
cd /opt/[projeto]_gtm/gtm-preview-[projeto] && docker-compose restart
```

### Ver logs
```bash
# Container principal
cd /opt/[projeto]_gtm/gtm-[projeto] && docker-compose logs -f

# Container preview
cd /opt/[projeto]_gtm/gtm-preview-[projeto] && docker-compose logs -f
```

## ❓ Troubleshooting

### Se o preview não funcionar:
- Limpe o cache do navegador
- Reinicie o Tag Assistant
- Verifique os logs: `docker-compose logs -f`

### Se aparecer erro 502:
- Verifique se os containers estão rodando: `docker ps`
- Verifique os logs: `docker-compose logs -f`
- Verifique se o Caddy está rodando: `systemctl status caddy`

## 📄 Arquivo de Configuração

O instalador cria um arquivo `project.conf` em `/opt/[projeto]_gtm/` com:
- Nome do projeto
- URLs configuradas
- Data de instalação

## 🆘 Suporte

Encontrou algum problema? [Abra uma issue](https://github.com/johnwalkerdev/gtm-server-installer/issues) 