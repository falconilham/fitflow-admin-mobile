// Navigation type definitions for the app

export type RootStackParamList = {
  Auth: undefined;
  Main: undefined;
};

export type MembersStackParamList = {
  MembersList: undefined;
  MemberDetail: { memberId: number };
  AddMember: undefined;
  EditMember: { memberId: number };
  ImportMember: undefined;
  RenewMember: { memberId: number };
};

export type StoreStackParamList = {
  StoreMain: undefined;
  AddProduct: undefined;
  EditProduct: { productId: number };
};

export type MainTabParamList = {
  Dashboard: undefined;
  CheckIn: undefined;
  Members: undefined;
  Store: undefined;
  Profile: undefined;
};
