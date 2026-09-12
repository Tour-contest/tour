import { adminAuthenticate } from "@/service/auth";

const useAuth = () => {
    // 에러를 여기서 삼키지 않고 호출부(useActionState의 action)로 던져서 폼 상태로 반영한다
    const requestAdminLogin = async (id: string, password: string) => {
        return await adminAuthenticate(id, password);
    }

    return { requestAdminLogin }
}
export default useAuth;