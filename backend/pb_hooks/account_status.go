package pb_hooks

import (
	"math"
	"time"

	"github.com/pocketbase/pocketbase/core"
)

func RegisterAccountStatusRoute(e *core.ServeEvent) {
	e.Router.POST("/api/account/status", func(req *core.RequestEvent) error {
		user := req.Auth
		if user == nil {
			return req.JSON(401, map[string]any{"message": "Unauthorized"})
		}

		markedForDeletion := user.GetBool("marked_for_deletion")
		requestTime := user.GetDateTime("request_time")

		resp := map[string]any{
			"markedForDeletion": markedForDeletion,
			"daysRemaining":     nil,
		}

		if markedForDeletion && !requestTime.Time().IsZero() {
			elapsed := time.Since(requestTime.Time())
			days := 5 - int(math.Ceil(elapsed.Hours()/24))
			if days < 0 {
				days = 0
			}
			resp["daysRemaining"] = days
		}

		return req.JSON(200, resp)
	})
}
