extends ResultScreen
## Tela de vitoria (camada app): o Guardiao venceu a Peleja.
##
## Sem regra propria -- a base desenha o modelo do `ResultAdapter` e o
## `GameFlowService` decide que a campanha segue para a proxima Peleja.


func result_kind() -> String:
	return ResultAdapter.KIND_VICTORY
