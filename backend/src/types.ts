/* eslint-disable @typescript-eslint/no-namespace -- Express request
   augmentation requires the global namespace declaration-merge. */
declare global {
  namespace Express {
    interface Request {
      user?: {
        id: string;
        name: string;
        email: string;
        username: string;
      };
    }
  }
}

export {};
