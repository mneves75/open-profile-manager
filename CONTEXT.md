# Open Profile Manager

Open Profile Manager permite escolher explicitamente qual identidade local do Codex inicia uma execução, mantendo credenciais sob controle do Codex oficial.

## Language

**Conta**:
A identidade autenticada pelo Codex oficial e responsável pelo uso de um turno.
_Avoid_: Perfil

**Perfil**:
Uma seleção local nomeada que aponta para o estado isolado de uma conta e pode iniciar o Codex.
_Avoid_: Conta, usuário

**Perfil participante**:
Um perfil ao qual o usuário concedeu acesso explícito ao pool de sessões compartilhadas.
_Avoid_: Perfil global

**Sessão compartilhada**:
Uma conversa local retomável por qualquer perfil participante; a conta do perfil escolhido é responsável por cada novo turno.
_Avoid_: Sessão global, sessão sincronizada

**Pool de sessões compartilhadas**:
O conjunto local de sessões compartilhadas e do estado retomável associado, acessível somente aos perfis participantes do mesmo usuário do macOS.
_Avoid_: Nuvem de sessões, perfil compartilhado
