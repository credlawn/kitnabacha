package pb_hooks

import (
	"log"
	"time"

	"github.com/getsentry/sentry-go"
)

func InitSentry() func() {
	if err := sentry.Init(sentry.ClientOptions{
		Dsn: "https://53c2213a4f84b960e8b88657d1734542@o4511670483550208.ingest.de.sentry.io/4511670682714192",
	}); err != nil {
		log.Fatalf("sentry.Init: %s", err)
	}
	return func() {
		sentry.Flush(2 * time.Second)
	}
}
