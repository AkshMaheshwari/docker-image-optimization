const request = require('supertest');
const app = require('../src/server');

describe('GET /', () => {
  it('returns HTTP 200', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toBe(200);
  });
});

describe('GET /health', () => {
  it('returns HTTP 200', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
  });

  it('returns the expected JSON response', async () => {
    const res = await request(app).get('/health');
    expect(res.body).toEqual({ status: 'healthy' });
  });
});
