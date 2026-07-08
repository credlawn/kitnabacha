routerAdd('POST', '/api/auth/google', (c) => {
  const body = JSON.parse(c.request.body());
  const idToken = body.idToken;

  if (!idToken) {
    return c.json(400, { message: 'idToken is required' });
  }

  const res = $http.send({
    url: 'https://oauth2.googleapis.com/tokeninfo?id_token=' + encodeURIComponent(idToken),
    method: 'GET',
  });

  if (res.statusCode !== 200) {
    return c.json(401, { message: 'Invalid ID token' });
  }

  const payload = JSON.parse(res.body);
  const email = payload.email;
  if (!email) {
    return c.json(400, { message: 'Email not available from Google' });
  }

  const name = payload.name || email.split('@')[0];

  let user;
  try {
    user = $app.dao().findFirstRecordByData('users', 'email', email);
  } catch (e) {
    user = null;
  }

  if (!user) {
    user = new Record($app.dao().findCollectionByNameOrId('users'));
    const randomPass = crypto.randomUUID().split('-')[0];
    user.set('email', email);
    user.set('name', name);
    user.set('verified', true);
    user.set('password', randomPass + 'Aa1@');
    user.set('passwordConfirm', randomPass + 'Aa1@');
    $app.dao().saveRecord(user);
  }

  const token = $app.dao().getToken(user);

  return c.json(200, {
    token: token,
    record: user,
  });
});
