package pb_hooks

import (
	"fmt"

	"github.com/pocketbase/pocketbase/core"
)

const privacyHTML = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Privacy Policy | Ledgeo</title>
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
  .tag { display: inline-block; padding: 2px 10px; border-radius: 4px; font-size: 13px; font-weight: 600; }
  .tag-collect { background: #dbeafe; color: #1e40af; }
  .tag-not { background: #fef3c7; color: #92400e; }
  .tag-share { background: #d1fae5; color: #065f46; }
  table { width: 100%; border-collapse: collapse; margin: 16px 0 20px; font-size: 14px; }
  table th, table td { padding: 10px 14px; text-align: left; border-bottom: 1px solid #eef0f4; }
  table th { background: #f7f8fa; font-weight: 600; color: #152450; }
  table tr:last-child td { border-bottom: none; }
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
    table { font-size: 13px; }
    table th, table td { padding: 8px 10px; }
    .footer { padding: 20px; }
  }
</style>
</head>
<body>

<div class="container">
  <div class="page">
    <div class="page-header">
      <h1>Privacy Policy</h1>
      <p class="date">Last updated: July 2026 · Effective: July 8, 2026</p>
    </div>
    <div class="content">

      <p>Ledgeo is a personal finance tracking application developed by Credlawn India. This Privacy Policy explains how we collect, use, store, and protect your personal data when you use our application and website. By using Ledgeo, you agree to the practices described in this policy.</p>
      <p>If you have any questions, contact us at <a href="mailto:admin@credlawn.com">admin@credlawn.com</a>.</p>

      <h2>1. Information We Collect</h2>
      <p>We collect only the data necessary to provide and improve our service. The table below summarises what we collect and why.</p>

      <table>
        <tr>
          <th>Data</th>
          <th>Purpose</th>
          <th>Required?</th>
        </tr>
        <tr>
          <td>Email address &amp; name</td>
          <td>Account identification and authentication (via Google Sign-In)</td>
          <td><span class="tag tag-collect">Yes</span></td>
        </tr>
        <tr>
          <td>Transactions, in-app payee names/contacts, expenses, budgets, debts</td>
          <td>Core app functionality — you enter this data to track your finances</td>
          <td><span class="tag tag-collect">As entered by you</span></td>
        </tr>
        <tr>
          <td>App usage &amp; crash diagnostics</td>
          <td>Bug detection and performance improvement</td>
          <td><span class="tag tag-collect">Automatically</span></td>
        </tr>
      </table>

      <h2>2. What We Do NOT Collect</h2>
      <div class="box">
        <p>✕ We do <strong>not</strong> sell or rent your personal data.</p>
        <p>✕ We do <strong>not</strong> share your data with third parties for advertising or marketing.</p>
        <p>✕ We do <strong>not</strong> analyse, categorise, or profile your spending habits.</p>
        <p>✕ We do <strong>not</strong> collect location data, device contacts, photos, or any data outside the app.</p>
        <p>✕ We do <strong>not</strong> use cookies or tracking scripts on our website.</p>
      </div>

      <h2>3. How We Use Your Data</h2>
      <p>Your data is used exclusively for the following purposes:</p>
      <ul>
        <li><strong>Account management:</strong> Your email and name identify your account and allow you to sign in securely via Google.</li>
        <li><strong>Data storage &amp; sync:</strong> Your financial records are stored on our server to provide backup and multi-device synchronisation. You are the owner of this data at all times.</li>
        <li><strong>Service improvement:</strong> Anonymous crash reports help us identify and fix bugs. These reports contain no personal or financial information.</li>
      </ul>

      <h2>4. Data Storage &amp; Security</h2>
      <p>Your data is stored on secure servers located in Mumbai, India. We implement industry-standard security measures:</p>
      <ul>
        <li>All data transmitted between the app and our server is encrypted using TLS 1.2 or higher.</li>
        <li>Passwords are hashed and never stored in plain text.</li>
        <li>Access to the server is restricted to authorised personnel only.</li>
        <li>We conduct regular security reviews and apply updates promptly.</li>
      </ul>
      <p>Despite these measures, no method of electronic storage or transmission is 100% secure. We cannot guarantee absolute security, but we take every reasonable precaution to protect your data.</p>

      <h2>5. Data Retention</h2>
      <p>We retain your data only as long as your account is active or as needed to provide the service:</p>
      <ul>
        <li><strong>Account data</strong> (email, name): retained while your account exists.</li>
        <li><strong>Financial records</strong> (transactions, contacts, etc.): retained while your account exists. You can delete individual records at any time from within the app.</li>
        <li><strong>Crash reports</strong>: retained for 90 days in aggregate, anonymous form.</li>
      </ul>
      <p>When you delete your account from the app, your account is marked for deletion and you are signed out. You have <strong>5 days</strong> to cancel by logging back in. After this grace period, all your personal data and financial records are permanently removed from our server within 5–7 days.</p>

      <h2>6. Data Sharing &amp; Third Parties</h2>
      <p>We do not share your personal data with third parties except in the following limited circumstances:</p>
      <table>
        <tr>
          <th>Third Party</th>
          <th>Service</th>
          <th>Data Shared</th>
        </tr>
        <tr>
          <td>Google LLC</td>
          <td>Google Sign-In (authentication)</td>
          <td>Email &amp; name (only at sign-in)</td>
        </tr>
        <tr>
          <td>Functional Software, Inc.</td>
          <td>Crash reporting &amp; diagnostics</td>
          <td>Anonymous crash data, no personal identifiers</td>
        </tr>
      </table>
      <p>Each third party processes data according to its own privacy policy. We have data processing agreements in place where required.</p>

      <h2>7. Your Rights &amp; Controls</h2>
      <p>You have full control over your data. You can:</p>
      <ul>
        <li><strong>Access</strong> — View all data you have entered at any time from within the app.</li>
        <li><strong>Export</strong> — Export your data from the Settings screen.</li>
        <li><strong>Delete records</strong> — Delete individual transactions or contacts from the app.</li>
        <li><strong>Delete account</strong> — Permanently delete your account and all associated data from Settings → Delete Account.</li>
        <li><strong>Withdraw consent</strong> — You may stop using the app at any time. Your data on your device remains yours. When you delete your account, you have <strong>5 days</strong> to cancel by logging in; after that, server data is removed within 5–7 days.</li>
      </ul>

      <h2>8. Children's Privacy</h2>
      <p>Ledgeo is not intended for use by individuals under the age of 13. We do not knowingly collect personal data from children. If you believe a child has provided us with personal data, please contact us at <a href="mailto:admin@credlawn.com">admin@credlawn.com</a> and we will promptly delete it.</p>

      <h2>9. Changes to This Policy</h2>
      <p>We may update this Privacy Policy from time to time. Changes will be posted on this page with an updated "Last updated" date. If the changes are material, we will notify you within the app. We encourage you to review this policy periodically.</p>

      <h2>10. Contact</h2>
      <p>If you have any questions, concerns, or requests regarding this Privacy Policy or your data, please contact us:</p>
      <div class="box">
        <p><strong>Email:</strong> <a href="mailto:admin@credlawn.com">admin@credlawn.com</a></p>
        <p><strong>Grievance Officer:</strong> <a href="mailto:admin@credlawn.com">admin@credlawn.com</a></p>
        <p><strong>Developer:</strong> Credlawn India</p>
      </div>

    </div>
    <div class="footer">
      <p>&copy; 2026 Credlawn India. All rights reserved. &middot; <a href="/privacy">Privacy Policy</a></p>
    </div>
  </div>
</div>

</body>
</html>`

func RegisterPrivacyRoute(e *core.ServeEvent) {
	e.Router.GET("/privacy", func(req *core.RequestEvent) error {
		req.Response.Header().Set("Content-Type", "text/html; charset=utf-8")
		fmt.Fprint(req.Response, privacyHTML)
		return nil
	})
}
