import { createAsyncThunk, createSlice, PayloadAction } from '@reduxjs/toolkit';
import axios from 'axios';
import Config from 'react-native-config';

const API_URL = Config.API_URL ?? 'https://api.fitflow.id';

export interface AdminInfo {
  id: number;
  name: string;
  email: string;
  role: 'owner' | 'admin';
  gymId: number;
  gymName?: string;
  Gym?: {
    id: number;
    name: string;
    subdomain: string;
    logo?: string;
    features?: string[];
  };
}

interface AuthState {
  token: string | null;
  admin: AdminInfo | null;
  activeGymId: number | null;
  status: 'idle' | 'loading' | 'succeeded' | 'failed';
  error: string | null;
}

const initialState: AuthState = {
  token: null,
  admin: null,
  activeGymId: null,
  status: 'idle',
  error: null,
};

export const loginThunk = createAsyncThunk(
  'auth/login',
  async (
    credentials: { email: string; password: string },
    { rejectWithValue },
  ) => {
    try {
      const response = await axios.post(`${API_URL}/admin/login`, credentials);
      return response.data; // { token, admin }
    } catch (err: any) {
      const message =
        err?.response?.data?.message ||
        err?.response?.data?.error ||
        'Login failed';
      return rejectWithValue(message);
    }
  },
);

const authSlice = createSlice({
  name: 'auth',
  initialState,
  reducers: {
    logout(state) {
      state.token = null;
      state.admin = null;
      state.activeGymId = null;
      state.status = 'idle';
      state.error = null;
    },
    setActiveGym(state, action: PayloadAction<number>) {
      state.activeGymId = action.payload;
    },
    clearError(state) {
      state.error = null;
    },
  },
  extraReducers: builder => {
    builder
      .addCase(loginThunk.pending, state => {
        state.status = 'loading';
        state.error = null;
      })
      .addCase(loginThunk.fulfilled, (state, action) => {
        state.status = 'succeeded';
        state.token = action.payload.token;
        state.admin = action.payload.admin;
        // Default active gym: the admin's own gym
        state.activeGymId = action.payload.admin?.gymId ?? null;
      })
      .addCase(loginThunk.rejected, (state, action) => {
        state.status = 'failed';
        state.error = action.payload as string;
      });
  },
});

export const { logout, setActiveGym, clearError } = authSlice.actions;
export default authSlice.reducer;
