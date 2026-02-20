import axios from 'axios';
import Config from 'react-native-config';
import { store } from '../store';
import { logout } from '../store/authSlice';

export const API_URL = Config.API_URL ?? 'https://api.fitflow.id';

const api = axios.create({
  baseURL: API_URL,
  timeout: 15000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Inject Bearer token from Redux store on every request
api.interceptors.request.use(config => {
  const token = store.getState().auth?.token;
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Auto-logout on 401
api.interceptors.response.use(
  response => response,
  error => {
    console.error(
      'API Error:',
      error?.message,
      error?.response?.data,
      error?.config?.url,
    );
    if (error?.response?.status === 401) {
      store.dispatch(logout());
    }
    return Promise.reject(error);
  },
);

export default api;
