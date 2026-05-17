# Bitacora

## 2026-05-17 — v0.0.1 Bootstrap del mundo office

### Objetivo de esta iteracion

Levantar el primer mundo de oficina de Trivium en GCP usando Terraform, con Luanti + VoxeLibre, accesible desde un cliente local por el dominio `office.cacsi.dev`.

Esta iteracion corresponde a la release `0.0.1` definida en [docs/roadmap.md](docs/roadmap.md).

### Alcance fijado

- `0.0.1` solo cubre infraestructura y conectividad base.
- No incluye mod de Trivium.
- No incluye voz espacial.
- No incluye backend, auth, pagos ni companion app.
- La prueba de aceptacion de esta fase es poder entrar al mundo desde el PC local usando Luanti.

---

## Lo que se hizo

### 1. Se redefinio la fase 0.0.x

Se separo `0.0.x` en micro-releases para no mezclar riesgo de infraestructura con riesgo de gameplay:

- `0.0.1`: bootstrap del mundo office en GCP.
- `0.0.2`: carga segura del mod de Trivium.
- `0.0.3`: chat de texto por proximidad.

Esto quedo documentado en [docs/roadmap.md](docs/roadmap.md).

### 2. Se adopto Terraform con TDD

Se decidio usar Terraform desde el dia uno para que la infraestructura sea reproducible y escalable.

Se implementaron dos stacks:

- [code/infra/bootstrap/main.tf](code/infra/bootstrap/main.tf): proyecto GCP, APIs base y bucket de estado.
- [code/infra/office/main.tf](code/infra/office/main.tf): IP, firewall y VM del mundo office.

Se escribieron tests antes de completar la implementacion:

- [code/infra/bootstrap/bootstrap.tftest.hcl](code/infra/bootstrap/bootstrap.tftest.hcl)
- [code/infra/office/office.tftest.hcl](code/infra/office/office.tftest.hcl)

Validaciones ejecutadas:

- `terraform test`
- `terraform validate`

---

## Recursos creados en GCP

### Proyecto

- Nombre e ID: `cacsi-virtual-office`

### APIs habilitadas

- `compute.googleapis.com`
- `dns.googleapis.com`
- `storage.googleapis.com`

### Estado remoto de Terraform

- Bucket: `cacsi-virtual-office-tfstate`

### Servidor office

- Instancia: `office-server`
- Zona: `us-central1-a`
- Tipo inicial: `e2-small`
- IP estatica: `34.55.29.155`
- Puerto de juego: UDP `30000`

### DNS

- Dominio: `office.cacsi.dev`
- Gestionado manualmente en Namecheap mediante registro A
- Valor actual: `34.55.29.155`

---

## Estado actual confirmado

### Infraestructura

- El proyecto GCP existe.
- La IP estatica existe.
- El firewall para UDP `30000` existe.
- El firewall SSH restringido existe.
- La VM existe y esta en `RUNNING`.
- `office.cacsi.dev` ya resuelve a `34.55.29.155`.

### Servidor de juego

- El startup script termino correctamente.
- El servicio systemd `trivium-office` esta en `active`.
- El proceso final en ejecucion es `luantiserver`.
- El servidor esta escuchando en `0.0.0.0:30000`.
- El mundo fue creado en `/opt/luanti/worlds/office`.
- El juego cargado es `VoxeLibre`.
- El perfil actual del mundo es `survival`: sin creativo, con dano, con respawn permitido y con `mob_difficulty = 3.0`.
- El worldmod `trivium_access` ya esta cargado y persistiendo estado en `mod_storage`.
- La whitelist ya existe a nivel de mundo y bloquea registros no autorizados.
- La cuenta bootstrap con administracion del mundo es `ccisnedev`.
- `Javier` permanece permitido, pero ya no es administrador bootstrap.

Mensaje de log confirmado durante el arranque:

- `Server for gameid="VoxeLibre" listening on 0.0.0.0:30000.`

### Cliente local

- Esta maquina ya tiene Luanti instalado por `winget`.
- Version detectada localmente: `5.15.2`.
- Se valido conexion real desde el PC local a `office.cacsi.dev:30000` con carga correcta del mundo.

---

## Errores encontrados y correcciones

### Error 1. Debian 12 no trae paquetes instalables del server

Primer intento fallido:

- `apt-get install -y luanti-server`
- `apt-get install -y minetestserver`

Resultado:

- Ambos paquetes fallaron con `Unable to locate package`.

Correccion aplicada:

- Compilar Luanti `5.16.1` desde fuente oficial en la VM.
- Se desactivo build de cliente.
- Se desactivaron unit tests y documentacion para reducir tiempo de build.

Implementado en [code/infra/office/scripts/startup.sh](code/infra/office/scripts/startup.sh).

### Error 2. La URL inicial de VoxeLibre no sirvio para bootstrap no interactivo

Primer intento fallido:

- `https://codeberg.org/VoxeLibre/VoxeLibre.git`

Sintoma:

- El clone terminaba redirigiendo a login o fallando de forma no interactiva.

Correccion aplicada:

- Se cambio a un repo publico accesible por clone anonimo:
- `https://codeberg.org/tacotexmex/voxelibre.git`

### Error 3. SSH a GCE fallaba por el nombre de usuario derivado automaticamente

Sintoma:

- `gcloud compute ssh office-server ...` intentaba crear o usar un usuario local numerico de Windows y fallaba.

Leccion:

- En esta maquina conviene conectarse siempre con usuario explicito.

Forma correcta:

- `gcloud compute ssh ccisnedev@office-server --project=cacsi-virtual-office --zone=us-central1-a ...`

### Error 4. Host key cambiada al recrear la VM

Como Terraform reemplazo la instancia varias veces durante el ajuste del startup script:

- la host key SSH cambio
- Plink mostro advertencia de fingerprint distinta

Esto fue esperado porque la VM fue destruida y recreada.

### Error 5. El primer perfil del mundo quedo en creativo e invulnerable

Sintoma:

- Al entrar al mundo, el jugador aparecia en creativo o con comportamiento equivalente a `god mode`.

Causa:

- El bootstrap habia dejado `creative_mode = true`.
- El bootstrap habia dejado `enable_damage = false`.

Correccion aplicada:

- Se cambio el servidor a `survival` con `creative_mode = false`.
- Se activo el dano con `enable_damage = true`.
- Se dejaron explicitados `enable_bed_respawn = true` y `mcl_return_spawn = true` para que siempre exista respawn normal.
- Se fijo `mob_difficulty = 3.0` como perfil alto de dificultad.
- Se migraron las cuentas ya creadas en el mundo para quitar `fly`, fijar `gamemode = survival` y limpiar la mano interna `mcl_meshhand` que seguia arrastrando toolcaps de creativo.

Nota tecnica:

- VoxeLibre no expone una dificultad maxima cerrada tipo `easy/normal/hard`; usa el multiplicador numerico `mob_difficulty`.
- En esta iteracion se fijo `3.0` como dificultad alta explicita y reproducible.
- En VoxeLibre, cambiar `minetest.conf` no siempre corrige a jugadores ya creados: el gamemode y ciertos toolcaps pueden quedar persistidos en `worlds/<world>/players/*` y requerir migracion manual.

---

## Decisiones tecnicas relevantes

### 1. Terraform se queda

No se vuelve a provisionar esta infraestructura a mano. La fuente de verdad es Terraform.

### 2. El DNS de office se gestiona fuera de GCP por ahora

No hay zona Cloud DNS para `cacsi.dev` en este proyecto. El registro se maneja manualmente en Namecheap.

### 3. Para v0.0.1 se acepta build desde fuente en la VM

No es la solucion ideal para largo plazo, pero es valida para bootstrap. Mas adelante convendra:

- usar una imagen prehorneada
- o publicar un artefacto propio
- o preparar una VM snapshot/base image

### 4. La maquina `e2-small` sirve para arrancar, no para crecer

El tipo de maquina esta parametrizado. Si hace falta mas margen:

- cambiar `machine_type` en Terraform
- reaplicar

Esto normalmente reinicia o reemplaza la VM, pero mantiene la IP estatica si sigue declarada aparte.

### 5. `code/mod/trivium_access` es la unica fuente de verdad

La primera implementacion dejo una copia embebida del worldmod dentro del startup script. Eso se corrigio.

Estado correcto actual:

- El codigo fuente del mod vive en [code/mod/trivium_access/init.lua](code/mod/trivium_access/init.lua).
- Terraform inyecta esos archivos al `startup.sh` al construir `metadata_startup_script`.
- El despliegue ya no mantiene una segunda copia manual del codigo del mod dentro del bootstrap.

---

## Comandos utiles

### Ver estado del servicio del mundo

```powershell
gcloud compute ssh ccisnedev@office-server --project=cacsi-virtual-office --zone=us-central1-a --command "sudo systemctl is-active trivium-office; sudo journalctl -u trivium-office -n 80 --no-pager"
```

### Ver estado del startup script

```powershell
gcloud compute ssh ccisnedev@office-server --project=cacsi-virtual-office --zone=us-central1-a --command "sudo systemctl is-active google-startup-scripts; sudo journalctl -u google-startup-scripts.service -n 80 --no-pager"
```

### Ver salida serial de la VM

```powershell
gcloud compute instances get-serial-port-output office-server --project=cacsi-virtual-office --zone=us-central1-a --port=1
```

### Verificar resolucion DNS

```powershell
nslookup office.cacsi.dev
```

### Administrar usuarios desde el juego

Estas operaciones ya no requieren editar `auth.txt` a mano. Se hacen desde una cuenta con privilegio `trivium_admin`.

Cuenta bootstrap actual con ese privilegio:

- `ccisnedev`

```text
/trivium_whitelist
/trivium_whitelist on
/trivium_whitelist off
/trivium_allow <jugador>
/trivium_allow <jugador> survival
/trivium_allow <jugador> creative
/trivium_admin <jugador> on
/trivium_admin <jugador> off
/trivium_deny <jugador>
/trivium_user <jugador>
```

Ejemplos utiles:

- Permitir que entre un nuevo arquitecto en creativo:
	`/trivium_allow Arquitecto creative`
- Darle tambien permisos de administracion del whitelist:
	`/trivium_admin Arquitecto on`
- Quitar acceso a un usuario:
	`/trivium_deny Invitado`

Comportamiento:

- Si la whitelist esta en `on`, un nombre no autorizado no puede registrarse ni entrar.
- `creative` se aplica por usuario al entrar al mundo.
- `survival` se reaplica al volver a entrar si el usuario no esta marcado como creativo.
- `trivium_deny` expulsa al jugador si esta conectado.

### Aplicar infraestructura office

```powershell
terraform apply -auto-approve -var "project_id=cacsi-virtual-office" -var 'admin_cidrs=["190.119.218.98/32"]'
```

Nota: `admin_cidrs` refleja la IP publica usada durante esta iteracion y puede cambiar.

---

## Archivos importantes creados o modificados

- [docs/roadmap.md](docs/roadmap.md)
- [code/infra/bootstrap/versions.tf](code/infra/bootstrap/versions.tf)
- [code/infra/bootstrap/variables.tf](code/infra/bootstrap/variables.tf)
- [code/infra/bootstrap/main.tf](code/infra/bootstrap/main.tf)
- [code/infra/bootstrap/outputs.tf](code/infra/bootstrap/outputs.tf)
- [code/infra/bootstrap/bootstrap.tftest.hcl](code/infra/bootstrap/bootstrap.tftest.hcl)
- [code/infra/office/versions.tf](code/infra/office/versions.tf)
- [code/infra/office/variables.tf](code/infra/office/variables.tf)
- [code/infra/office/main.tf](code/infra/office/main.tf)
- [code/infra/office/outputs.tf](code/infra/office/outputs.tf)
- [code/infra/office/office.tftest.hcl](code/infra/office/office.tftest.hcl)
- [code/infra/office/scripts/startup.sh](code/infra/office/scripts/startup.sh)

---

## Punto exacto en el que estamos

`v0.0.1` ya valido infraestructura remota y conexion real desde cliente local.

Pendientes para cerrar formalmente la release:

- reiniciar la VM y comprobar reconexion sin perder el mundo

Despues de eso, el siguiente trabajo ya es `0.0.2`: instalar el esqueleto del mod de Trivium sin romper VoxeLibre.
