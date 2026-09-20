import axios from 'axios'
import { authenticate, badRequest } from './exception'
import attachRefreshToken from './attachRefreshToken'

export const axiosInstance = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL,
  timeout: 10000,
  withCredentials: true,
  headers: {
    'Content-Type': 'application/json',
  },
})

// Bearer 부착 + 선제 refresh (request)
attachRefreshToken(axiosInstance)
// error exception 400
badRequest(axiosInstance)
// error exception 401
authenticate(axiosInstance)
