(async function () {
  const status = document.getElementById('status');
  try {
    const response = await fetch('/api/message');
    if (!response.ok) {
      throw new Error('request failed with status ' + response.status);
    }
    const payload = await response.json();
    status.textContent = payload.message;
  } catch (err) {
    status.textContent = 'Failed to reach backend: ' + err.message;
  }
})();
