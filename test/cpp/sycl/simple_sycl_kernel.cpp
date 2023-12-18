#include <sycl/sycl.hpp>

class SimpleKer {
 public:
  SimpleKer(float* a) : a_(a) {}
  void operator()(sycl::item<1> item) const { a_[item] = item; }
 private:
  float* a_;
};

void itoa(float* res, int numel){
  sycl::device dev = sycl::device(sycl::gpu_selector());
  sycl::queue q = sycl::queue(dev, sycl::property_list());

  float* a = sycl::malloc_shared<float>(numel, q);
  auto cgf = [&](sycl::handler& cgh) {
    cgh.parallel_for<SimpleKer>(sycl::range<1>(numel), SimpleKer(a));
  };

  auto e = q.submit(cgf);
  e.wait();

  memcpy(res, a, numel * sizeof(float));
  sycl::free(a, q);

  return;
}
