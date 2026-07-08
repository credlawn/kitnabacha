package main

import (
	"log"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/hook"

	"custompb/pb_hooks"
)

func main() {
	defer pb_hooks.InitSentry()()

	app := pocketbase.New()

	app.OnServe().Bind(&hook.Handler[*core.ServeEvent]{
		Func: func(e *core.ServeEvent) error {
			if err := bootstrapCollections(e.App); err != nil {
				return err
			}
			pb_hooks.RegisterPrivacyRoute(e)
			pb_hooks.RegisterAccountDeletionRoute(e)
			pb_hooks.RegisterDeleteAccountRoute(e)
			pb_hooks.RegisterAccountStatusRoute(e)
			pb_hooks.RegisterRestoreAccountRoute(e)
			pb_hooks.RegisterGoogleAuthRoute(e)
			return e.Next()
		},
		Priority: 999,
	})

	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}
