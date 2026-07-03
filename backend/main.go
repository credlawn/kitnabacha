package main

import (
	"log"
	"time"

	"github.com/getsentry/sentry-go"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/hook"
)

func main() {
	if err := sentry.Init(sentry.ClientOptions{
		Dsn: "https://53c2213a4f84b960e8b88657d1734542@o4511670483550208.ingest.de.sentry.io/4511670682714192",
	}); err != nil {
		log.Fatalf("sentry.Init: %s", err)
	}
	defer sentry.Flush(2 * time.Second)

	app := pocketbase.New()

	app.OnServe().Bind(&hook.Handler[*core.ServeEvent]{
		Func: func(e *core.ServeEvent) error {
			if err := bootstrapCollections(e.App); err != nil {
				return err
			}
			return e.Next()
		},
		Priority: 999,
	})

	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}
