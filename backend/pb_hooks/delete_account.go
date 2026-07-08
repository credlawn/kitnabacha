package pb_hooks

import (
	"time"

	"github.com/pocketbase/pocketbase/core"
)

func RegisterDeleteAccountRoute(e *core.ServeEvent) {
	e.Router.POST("/api/account/delete", func(req *core.RequestEvent) error {
		user := req.Auth
		if user == nil {
			return req.JSON(401, map[string]any{"message": "Unauthorized"})
		}

		lg := req.App.Logger()
		lg.Info("delete_account: marking user for deletion", "user_id", user.Id, "email", maskEmail(user.Email()))

		user.Set("marked_for_deletion", true)
		user.Set("request_time", time.Now().UTC())

		if err := req.App.Save(user); err != nil {
			lg.Error("delete_account: failed to mark user for deletion", "error", err)
			return req.JSON(500, map[string]any{"message": "Failed to process deletion request"})
		}

		lg.Info("delete_account: user marked for deletion", "user_id", user.Id)
		return req.JSON(200, map[string]any{"message": "Deletion request submitted"})
	})
}
