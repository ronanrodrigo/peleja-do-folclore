# Testes com GUT, CI headless com godot-ci e regra de evidência por ticket

## Contexto

O jogo tem regras de combate que precisam ser verificadas sem abrir o editor, e o export web precisa
ser exercitado no CI. Subagentes tendem a declarar sucesso sem prova.

## Decisão

- Testes de domínio e aplicação com **GUT**, rodando headless (`-gexit`), usando adapters `sample/` em memória.
- CI no GitHub Actions com a imagem `barichello/godot-ci`, rodando lint (gdlint), testes e export web.
- Gate local `make verify` = lint + test + export.
- **Regra de evidência**: nenhum ticket ou PR fecha com "pronto" declarado; o fechamento exige prova
  executável (saída de teste, log de export, print do jogo rodando).

## Alternativas consideradas

- gdUnit4 (relatório de cobertura) — bom, mas GUT tem adoção maior e integração headless mais simples.
- Sem testes no v1 — inaceitável para regras de combate, balanceamento e Reviravolta.

## Consequências

- O domínio precisa ser puro o bastante para rodar sem engine, o que fixa a regra de não usar `Node` no domínio.
- O CI depende de baixar a imagem `godot-ci` e os export templates; o workflow precisa fixar a versão 4.7.
