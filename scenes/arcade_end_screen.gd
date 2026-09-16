extends ResultScreen
## Tela de fim de arcade (camada app): as sete Pelejas terminaram.
##
## O caminho de volta ao titulo e o comando de confirmar: o fluxo reinicia a
## campanha (`GameFlowService.back_to_title`).


func result_kind() -> String:
	return ResultAdapter.KIND_ARCADE_END
