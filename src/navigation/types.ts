// Navigation type definitions for the app

export type RootStackParamList = {
  Auth: undefined;
  Main: undefined;
};

export type MembersStackParamList = {
  MembersList: undefined;
  MemberDetail: { memberId: number };
  AddMember: undefined;
  ImportMember: undefined;
  RenewMember: { memberId: number };
};

export type MainTabParamList = {
  Dashboard: undefined;
  CheckIn: undefined;
  Members: undefined;
  Profile: undefined;
};
