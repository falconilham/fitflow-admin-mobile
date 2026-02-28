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

export const importMemberApi = (gymId: number, data: any) =>
  api.post('/admin/members/import', { ...data, gymId });

export const generateMemberIdApi = (gymId: number) =>
  api.get('/admin/members/generate-id', { params: { gymId } });

export const updateMemberApi = (memberId: number, data: any) =>
  api.put(`/admin/members/${memberId}`, data);

// Gym Settings
export const getGymSettingsPublicApi = (gymId: number) =>
  api.get('/admin/settings/public', { params: { gymId } });

// Membership Packages
export const getPackagesApi = (gymId: number) =>
  api.get('/admin/membership-packages', { params: { gymId } });

// Check-in
export const checkInByQrApi = (
  gymId: number,
  userId: number,
  membershipId: number,
) => api.post('/admin/check-in', { gymId, userId, membershipId });

export const getRecentCheckInsApi = (gymId: number, limit = 5) =>
  api.get('/admin/check-ins', { params: { gymId, limit } });

// POS — Products (mounted under /admin in backend)
export const getPosProductsApi = (gymId: number) =>
  api.get('/admin/products', { params: { gymId } });
export const createProductApi = (data: any) =>
  api.post('/admin/products', data);
export const updateProductApi = (id: number, data: any) =>
  api.put(`/admin/products/${id}`, data);
export const deleteProductApi = (id: number) =>
  api.delete(`/admin/products/${id}`);

// POS — Transactions (mounted under /admin in backend)
export const createTransactionApi = (data: any) =>
  api.post('/admin/transactions', data);
export const getTransactionsApi = (gymId: number) =>
  api.get('/admin/transactions', { params: { gymId } });
