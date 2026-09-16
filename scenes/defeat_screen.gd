extends ResultScreen
## Tela de derrota (camada app): o Oponente venceu a Peleja e a Forca
## Sobrenatural resolveu (a Reviravolta ja passou).
##
## A copy e explicita: a Peleja foi perdida, a CAMPANHA CONTINUA. Quem garante
## isso e o dominio (`ReviravoltaRule.keeps_campaign_alive`); aqui so se mostra.


func result_kind() -> String:
	return ResultAdapter.KIND_DEFEAT
