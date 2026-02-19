import api from './client';

// Auth
export const loginApi = (email: string, password: string) =>
  api.post('/admin/login', { email, password });

// Dashboard
export const getStatsApi = (gymId: number) =>
  api.get('/admin/stats', { params: { gymId } });

export const getMyGymsApi = () => api.get('/admin/my-gyms');

// Members
export const getMembersApi = (
  gymId: number,
  params?: { search?: string; status?: string; page?: number; limit?: number },
) => api.get('/admin/members', { params: { gymId, ...params } });

export const getMemberDetailApi = (memberId: number) =>
  api.get(`/admin/members/${memberId}`);

export const createMemberApi = (gymId: number, data: any) =>
  api.post('/admin/members', { ...data, gymId });

export const updateMemberApi = (memberId: number, data: any) =>
  api.put(`/admin/members/${memberId}`, data);

// Membership Packages
export const getPackagesApi = (gymId: number) =>
  api.get('/admin/membership-packages', { params: { gymId } });

// Check-in
export const checkInApi = (gymId: number, memberId: number) =>
  api.post('/admin/check-in', { gymId, memberId });

export const checkInByQrApi = (gymId: number, qrData: string) =>
  api.post('/admin/check-in/qr', { gymId, qrData });
