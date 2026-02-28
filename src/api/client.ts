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
  const state = store.getState();
  const token = state.auth?.token;
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  // Inject X-Gym-Id so extractGymContext middleware on the backend
  // can always resolve req.gymId (it reads X-Gym-Id as Priority 1).
  const activeGymId = state.auth?.activeGymId;
  if (activeGymId) {
    config.headers['X-Gym-Id'] = String(activeGymId);
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
