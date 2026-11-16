extends RefCounted
## Classe base dos testes. Métodos `test_*` são executados por tests/run_tests.gd.
## Hooks opcionais: before_each() e after_each() (podem usar await).

var tree: SceneTree
var assertions := 0
var failures: Array[String] = []


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func assert_true(condition: bool, message := "") -> void:
	assertions += 1
	if not condition:
		failures.append("esperava true. %s" % message)


func assert_false(condition: bool, message := "") -> void:
	assertions += 1
	if condition:
		failures.append("esperava false. %s" % message)


func assert_eq(actual: Variant, expected: Variant, message := "") -> void:
	assertions += 1
	if actual != expected:
		failures.append("esperava %s, veio %s. %s" % [str(expected), str(actual), message])


func assert_ne(actual: Variant, unexpected: Variant, message := "") -> void:
	assertions += 1
	if actual == unexpected:
		failures.append("esperava valor diferente de %s. %s" % [str(unexpected), message])


func assert_almost_eq(actual: float, expected: float, epsilon := 0.01, message := "") -> void:
	assertions += 1
	if absf(actual - expected) > epsilon:
		failures.append("esperava ~%s, veio %s. %s" % [str(expected), str(actual), message])


func assert_gt(actual: float, minimum: float, message := "") -> void:
	assertions += 1
	if not actual > minimum:
		failures.append("esperava > %s, veio %s. %s" % [str(minimum), str(actual), message])


func wait_physics_frames(count: int) -> void:
	for i in count:
		await tree.physics_frame


func wait_frames(count: int) -> void:
	for i in count:
		await tree.process_frame


## Asserção barata para laços longos: conta a asserção e devolve `condition`, sem montar mensagem.
## Uso: `if not ok(a.size.x > 0.0): fail("%s: largura zero" % label)` — a string só é formatada
## quando falha (formatar milhões de mensagens que passam custava segundos na suíte).
func ok(condition: bool) -> bool:
	assertions += 1
	return condition


## Registra uma falha com a mensagem dada (par de `ok`).
func fail(message: String) -> void:
	failures.append(message)
