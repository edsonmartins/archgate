package oracle

import "testing"

func TestStatementsPreserveEveryCommandInOrder(t *testing.T) {
	commands := []string{"CREATE USER test", "GRANT CREATE SESSION TO test", "GRANT SELECT TO test"}
	got := statementsMap(commands)
	if len(got) != 1 || got["sql"] != "CREATE USER test;GRANT CREATE SESSION TO test;GRANT SELECT TO test" {
		t.Fatalf("commands lost or duplicated: %#v", got)
	}
	if statementsMap(nil) != nil {
		t.Fatal("empty commands must remain empty")
	}
}
