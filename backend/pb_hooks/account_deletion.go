package pb_hooks

import (
	"fmt"

	"github.com/pocketbase/pocketbase/core"
)

const accountDeletionHTML = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Account Deletion | Ledgeo</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
    color: #1C1E21;
    line-height: 1.7;
    background: #f8f9fa;
  }
  .container { max-width: 1000px; margin: 0 auto; padding: 0 24px; }
  .page { background: #fff; margin: 32px auto; border-radius: 12px; box-shadow: 0 1px 4px rgba(0,0,0,0.06); overflow: hidden; }
  .page-header {
    background: linear-gradient(135deg, #152450 0%, #1e3a7a 100%);
    padding: 40px 48px 32px;
    color: #fff;
  }
  .page-header h1 { font-size: 28px; font-weight: 700; margin-bottom: 6px; }
  .page-header .date { opacity: 0.75; font-size: 14px; }
  .content { padding: 40px 48px 48px; }
  .content h2 {
    font-size: 18px;
    font-weight: 700;
    color: #152450;
    margin-top: 36px;
    margin-bottom: 12px;
    padding-bottom: 6px;
    border-bottom: 2px solid #eef0f4;
  }
  .content h2:first-child { margin-top: 0; }
  .content p { margin-bottom: 14px; }
  .content ul { margin-bottom: 14px; padding-left: 24px; }
  .content li { margin-bottom: 6px; }
  .content a { color: #1e3a7a; text-decoration: none; font-weight: 500; }
  .content a:hover { text-decoration: underline; }
  .box {
    background: #f7f8fa;
    border-left: 4px solid #152450;
    border-radius: 0 8px 8px 0;
    padding: 16px 20px;
    margin: 16px 0 20px;
  }
  .box p { margin: 4px 0; }
  .step { display: flex; gap: 12px; margin-bottom: 10px; align-items: flex-start; }
  .step-num {
    flex-shrink: 0;
    width: 28px; height: 28px;
    background: #152450;
    color: #fff;
    border-radius: 50%;
    display: flex; align-items: center; justify-content: center;
    font-size: 14px; font-weight: 700;
    margin-top: 2px;
  }
  .step-text { padding-top: 3px; }
  .option-card {
    background: #f7f8fa;
    border-radius: 10px;
    padding: 20px 24px;
    margin: 16px 0 24px;
  }
  .option-card h3 { color: #152450; font-size: 16px; margin-bottom: 12px; }
  .warning {
    background: #fef3c7;
    border-left: 4px solid #d97706;
    border-radius: 0 8px 8px 0;
    padding: 16px 20px;
    margin: 20px 0;
  }
  .warning p { margin: 4px 0; color: #92400e; }
  .footer {
    text-align: center;
    padding: 24px 48px;
    border-top: 1px solid #eef0f4;
    color: #65676b;
    font-size: 13px;
  }
  .footer a { color: #1e3a7a; text-decoration: none; }
  @media (max-width: 600px) {
    .page-header { padding: 28px 20px 24px; }
    .page-header h1 { font-size: 22px; }
    .content { padding: 24px 20px 32px; }
    .option-card { padding: 16px; }
    .footer { padding: 20px; }
  }
</style>
</head>
<body>

<div class="container">
  <div class="page">
    <div class="page-header">
      <h1>Account Deletion</h1>
      <p class="date">How to permanently delete your Ledgeo account and data</p>
    </div>
    <div class="content">

      <p>At Ledgeo, we respect your privacy and give you full control over your data. If you choose to delete your account, follow one of the options below. <strong>Deletion is irreversible once the 5-day grace period expires</strong> and will permanently erase all your data from our servers.</p>

      <h2>Option 1: Delete from the App (Recommended)</h2>
      <div class="option-card">
        <div class="step">
          <div class="step-num">1</div>
          <div class="step-text">Open the Ledgeo app.</div>
        </div>
        <div class="step">
          <div class="step-num">2</div>
          <div class="step-text">Go to <strong>Settings</strong> from the bottom navigation.</div>
        </div>
        <div class="step">
          <div class="step-num">3</div>
          <div class="step-text">Scroll down and tap <strong>Delete Account</strong>.</div>
        </div>
        <div class="step">
          <div class="step-num">4</div>
          <div class="step-text">Confirm the deletion when prompted.</div>
        </div>
      </div>
      <p>Once confirmed, your account will be marked for deletion and you will be signed out. You have <strong>5 days</strong> to cancel the process by simply logging back in. After this grace period, your account and all associated data will be permanently erased.</p>

      <h2>Option 2: Request Deletion via Email</h2>
      <div class="option-card">
        <div class="step">
          <div class="step-num">1</div>
          <div class="step-text">Send an email to <a href="mailto:admin@credlawn.com?subject=Account%20Deletion%20Request"><strong>admin@credlawn.com</strong></a> from your registered email address.</div>
        </div>
        <div class="step">
          <div class="step-num">2</div>
          <div class="step-text">Use the subject line: <strong>Account Deletion Request</strong>.</div>
        </div>
        <div class="step">
          <div class="step-num">3</div>
          <div class="step-text">Our team will process your request within <strong>7 days</strong> and send you a confirmation email once the deletion is complete.</div>
        </div>
      </div>

      <div class="warning">
        <p><strong>Important:</strong></p>
        <p>Once you initiate deletion, your account is marked for removal and you will be signed out. You can cancel the process at any time by logging back in within <strong>5 days</strong> of your request.</p>
        <p>After the 5-day grace period expires, your account and all associated data will be permanently erased from our servers within <strong>5–7 days</strong>. This action cannot be undone.</p>
        <p>Data stored locally on your device will not be affected; you can clear it by uninstalling the app.</p>
      </div>

      <h2>What Gets Deleted</h2>
      <ul>
        <li>Your profile (name, email address)</li>
        <li>All transactions, contacts, expense records, budgets, and debts</li>
        <li>Category and group preferences</li>
      </ul>

      <h2>What Is NOT Deleted</h2>
      <ul>
        <li>Data stored locally on your device (clear this manually or uninstall the app)</li>
        <li>Anonymous crash reports retained for diagnostic purposes (these contain no personal identifiers)</li>
      </ul>

      <h2>Need Help?</h2>
      <p>If you have any issues or questions about account deletion, contact us at <a href="mailto:admin@credlawn.com">admin@credlawn.com</a>.</p>

    </div>
    <div class="footer">
      <p>&copy; 2026 Credlawn India. All rights reserved. &middot; <a href="/privacy">Privacy Policy</a></p>
    </div>
  </div>
</div>

</body>
</html>`

func RegisterAccountDeletionRoute(e *core.ServeEvent) {
	e.Router.GET("/account-deletion", func(req *core.RequestEvent) error {
		req.Response.Header().Set("Content-Type", "text/html; charset=utf-8")
		fmt.Fprint(req.Response, accountDeletionHTML)
		return nil
	})
}
