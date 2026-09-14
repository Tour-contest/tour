import { getUser } from "@/service/user";

const useUser = () => {
    const fetchUsers = async (params?: GetUserParams) => {
        try {
            const res = await getUser(params);
            console.log({ res });
            return res;
        } catch (e) {
            console.error(e);
            return null;
        }
    };

    return { fetchUsers }
}
export default useUser;
